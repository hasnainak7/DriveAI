import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math'; 
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:http/http.dart' as http; // <--- NEW ML IMPORT

class OBDService {
  // Connections
  BluetoothConnection? _bluetoothConnection;
  Socket? _wifiSocket;
  bool _isSimulating = false;

  // Stream for Broadcasting Data to the UI
  final _obdDataController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get obdDataStream => _obdDataController.stream;

  // Buffer to handle fragmented serial data
  final StringBuffer _buffer = StringBuffer();

  // Connection State
  bool get isConnected => 
      (_bluetoothConnection != null && _bluetoothConnection!.isConnected) || 
      _wifiSocket != null || 
      _isSimulating;

  // ==========================================
  // 6. ML ENGINE STATE (NEW)
  // ==========================================
  Timer? _mlAnalysisTimer;
  
  double currentRpm = 0;
  double currentSpeed = 0;
  double currentLoad = 0;
  double currentCoolant = 90; // Default normal temp
  double currentIntake = 30;
  double currentThrottle = 15;

  // ==========================================
  // 1. HARDWARE CONNECTIONS
  // ==========================================

  Future<bool> connectToBluetooth(BluetoothDevice device) async {
    disconnect();
    try {
      _bluetoothConnection = await BluetoothConnection.toAddress(device.address);
      
      _bluetoothConnection!.input!.listen((Uint8List data) {
        String asciiData = ascii.decode(data);
        _handleRawData(asciiData);
      }).onDone(() {
        disconnect();
      });

      await _initializeOBD();
      return true;
    } catch (e) {
      print("Bluetooth Connection Error: $e");
      return false;
    }
  }

  Future<bool> connectToWiFi(String ip, int port) async {
    disconnect();
    try {
      _wifiSocket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      
      _wifiSocket!.listen((Uint8List data) {
        String asciiData = ascii.decode(data);
        _handleRawData(asciiData);
      }, onDone: () {
        disconnect();
      });

      await _initializeOBD();
      return true;
    } catch (e) {
      print("WiFi Connection Error: $e");
      return false;
    }
  }

  Future<bool> startSimulation() async {
    disconnect();
    _isSimulating = true;
    return true;
  }

  void disconnect() {
    stopMLAnalysisEngine(); // Stop ML when disconnected

    _bluetoothConnection?.dispose();
    _bluetoothConnection = null;
    
    _wifiSocket?.destroy();
    _wifiSocket = null;
    
    _isSimulating = false;
    _buffer.clear();
  }

  // ==========================================
  // 2. COMMAND PROTOCOL
  // ==========================================

  Future<void> _initializeOBD() async {
    // Standard ELM327 Initialization Sequence
    await sendCommand("ATZ\r"); // Reset
    await Future.delayed(const Duration(milliseconds: 500));
    await sendCommand("ATE0\r"); // Echo Off
    await Future.delayed(const Duration(milliseconds: 200));
    await sendCommand("ATL0\r"); // Linefeeds Off
    await Future.delayed(const Duration(milliseconds: 200));
    await sendCommand("ATSP0\r"); // Auto Protocol
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> sendCommand(String command) async {
    if (!isConnected) return;

    if (_isSimulating) {
      _generateSimulatedResponse(command);
      return;
    }

    try {
      if (_bluetoothConnection != null) {
        _bluetoothConnection!.output.add(ascii.encode(command));
        await _bluetoothConnection!.output.allSent;
      } else if (_wifiSocket != null) {
        _wifiSocket!.write(command);
      }
    } catch (e) {
      print("Error sending command: $e");
    }
  }

  // ==========================================
  // 3. RAW DATA HANDLING & HEX PARSING
  // ==========================================

  void _handleRawData(String data) {
    _buffer.write(data);
    String stream = _buffer.toString();

    // ELM327 terminates messages with the '>' prompt character
    if (stream.contains('>')) {
      List<String> messages = stream.split('>');
      for (int i = 0; i < messages.length - 1; i++) {
        String cleanMessage = messages[i].replaceAll('\r', '').replaceAll('\n', '').trim();
        if (cleanMessage.isNotEmpty) {
          _processResponse(cleanMessage);
        }
      }
      _buffer.clear();
      _buffer.write(messages.last); // Keep any incomplete data in the buffer
    }
  }

  void _processResponse(String response) {
    // Avoid parsing 'NO DATA' or errors
    if (response.contains("NO DATA") || response.contains("ERROR")) return;

    // --- MODE 01: LIVE TELEMETRY PARSERS ---
    
    // Engine RPM (PID 0C) -> Formula: ((A * 256) + B) / 4
    if (response.startsWith("41 0C") || response.startsWith("410C")) {
      List<String> parts = _splitHex(response, "41 0C");
      if (parts.length >= 2) {
        int a = int.parse(parts[0], radix: 16);
        int b = int.parse(parts[1], radix: 16);
        int rpm = ((a * 256) + b) ~/ 4;
        currentRpm = rpm.toDouble(); // Save for ML
        _obdDataController.add({'type': 'RPM', 'value': rpm});
      }
    }
    
    // Vehicle Speed (PID 0D) -> Formula: A
    else if (response.startsWith("41 0D") || response.startsWith("410D")) {
      List<String> parts = _splitHex(response, "41 0D");
      if (parts.isNotEmpty) {
        int a = int.parse(parts[0], radix: 16);
        currentSpeed = a.toDouble(); // Save for ML
        _obdDataController.add({'type': 'SPEED', 'value': a});
      }
    }
    
    // Engine Load (PID 04) -> Formula: A * 100 / 255
    else if (response.startsWith("41 04") || response.startsWith("4104")) {
      List<String> parts = _splitHex(response, "41 04");
      if (parts.isNotEmpty) {
        int a = int.parse(parts[0], radix: 16);
        int load = (a * 100) ~/ 255;
        currentLoad = load.toDouble(); // Save for ML
        _obdDataController.add({'type': 'LOAD', 'value': load});
      }
    }
    
    // Coolant Temp (PID 05) -> Formula: A - 40
    else if (response.startsWith("41 05") || response.startsWith("4105")) {
      List<String> parts = _splitHex(response, "41 05");
      if (parts.isNotEmpty) {
        int a = int.parse(parts[0], radix: 16);
        int coolant = a - 40;
        currentCoolant = coolant.toDouble(); // Save for ML
        _obdDataController.add({'type': 'COOLANT', 'value': coolant});
      }
    }

    // Intake Air Temp (PID 0F) -> Formula: A - 40
    else if (response.startsWith("41 0F") || response.startsWith("410F")) {
      List<String> parts = _splitHex(response, "41 0F");
      if (parts.isNotEmpty) {
        int a = int.parse(parts[0], radix: 16);
        int intake = a - 40;
        currentIntake = intake.toDouble(); // Save for ML
        _obdDataController.add({'type': 'INTAKE', 'value': intake});
      }
    }

    // Throttle Position (PID 11) -> Formula: A * 100 / 255
    else if (response.startsWith("41 11") || response.startsWith("4111")) {
      List<String> parts = _splitHex(response, "41 11");
      if (parts.isNotEmpty) {
        int a = int.parse(parts[0], radix: 16);
        int throttle = (a * 100) ~/ 255;
        currentThrottle = throttle.toDouble(); // Save for ML
        _obdDataController.add({'type': 'THROTTLE', 'value': throttle});
      }
    }

    // Distance Traveled Since Codes Cleared (PID 31) -> Formula: (A * 256) + B
    else if (response.startsWith("41 31") || response.startsWith("4131")) {
      List<String> parts = _splitHex(response, "41 31");
      if (parts.length >= 2) {
        int a = int.parse(parts[0], radix: 16);
        int b = int.parse(parts[1], radix: 16);
        int kmDriven = (a * 256) + b;
        _obdDataController.add({'type': 'DISTANCE', 'value': kmDriven});
      }
    }

    // --- MODE 03: DTC PARSING ---
    else if (response.startsWith("43")) {
      _parseDTCResponse(response);
    }
  }

  List<String> _splitHex(String response, String prefix) {
    String cleanResponse = response.replaceAll(' ', '');
    String cleanPrefix = prefix.replaceAll(' ', '');
    if (cleanResponse.length > cleanPrefix.length) {
      String data = cleanResponse.substring(cleanPrefix.length);
      List<String> bytes = [];
      for (int i = 0; i < data.length; i += 2) {
        if (i + 2 <= data.length) bytes.add(data.substring(i, i + 2));
      }
      return bytes;
    }
    return [];
  }

  // ==========================================
  // 4. DIAGNOSTIC TROUBLE CODES (DTC)
  // ==========================================

  Future<void> requestDTCs() async {
    if (_isSimulating) {
      await Future.delayed(const Duration(seconds: 2));
      _obdDataController.add({
        'type': 'DTC',
        'codes': ['P0301', 'P0420'] // Simulated codes
      });
      return;
    }
    await sendCommand("03\r"); // Mode 03: Request Emissions-related DTCs
  }

  Future<void> clearDTCs() async {
    if (_isSimulating) {
      await Future.delayed(const Duration(seconds: 1));
      _obdDataController.add({'type': 'DTC_CLEARED'});
      return;
    }
    await sendCommand("04\r"); // Mode 04: Clear/Reset Emission-related Diagnostic Info
    _obdDataController.add({'type': 'DTC_CLEARED'});
  }

  void _parseDTCResponse(String response) {
    String cleanResponse = response.replaceAll(' ', '');
    if (cleanResponse.length > 2) {
      String data = cleanResponse.substring(2);
      List<String> codes = [];
      for (int i = 0; i < data.length; i += 4) {
        if (i + 4 <= data.length) {
          String rawHex = data.substring(i, i + 4);
          if (rawHex != "0000") {
            codes.add("P${rawHex.substring(1)}"); 
          }
        }
      }
      _obdDataController.add({'type': 'DTC', 'codes': codes});
    }
  }

  // ==========================================
  // 5. DEVELOPER SIMULATION ENGINE (DYNAMIC)
  // ==========================================

  int _simRpmBase = 2500;
  int _simSpeedBase = 60;
  final Random _random = Random();

  void _generateSimulatedResponse(String command) {
    String mockResponse = "";
    String cmd = command.replaceAll('\r', '');

    if (cmd == "010C") {
      _simRpmBase += _random.nextInt(200) - 100; 
      if (_simRpmBase < 800) _simRpmBase = 800;
      if (_simRpmBase > 4000) _simRpmBase = 4000;
      
      int value = _simRpmBase * 4;
      int a = value ~/ 256;
      int b = value % 256;
      mockResponse = "41 0C ${a.toRadixString(16).padLeft(2, '0').toUpperCase()} ${b.toRadixString(16).padLeft(2, '0').toUpperCase()}>";
      
    } else if (cmd == "010D") {
      _simSpeedBase += _random.nextInt(5) - 2;
      if (_simSpeedBase < 0) _simSpeedBase = 0;
      if (_simSpeedBase > 120) _simSpeedBase = 120;
      mockResponse = "41 0D ${_simSpeedBase.toRadixString(16).padLeft(2, '0').toUpperCase()}>";
      
    } else if (cmd == "0104") {
      int load = 30 + _random.nextInt(20);
      int a = (load * 255) ~/ 100;
      mockResponse = "41 04 ${a.toRadixString(16).padLeft(2, '0').toUpperCase()}>";
      
    } else if (cmd == "0105") {
      int temp = 85 + _random.nextInt(10);
      int a = temp + 40;
      mockResponse = "41 05 ${a.toRadixString(16).padLeft(2, '0').toUpperCase()}>";
      
    } else if (cmd == "010F") {
      mockResponse = "41 0F 4B>";
      
    } else if (cmd == "0111") {
      int throttle = 10 + _random.nextInt(20);
      int a = (throttle * 255) ~/ 100;
      mockResponse = "41 11 ${a.toRadixString(16).padLeft(2, '0').toUpperCase()}>";
      
    } else if (cmd == "0131") {
      mockResponse = "41 31 14 00>";
    }

    if (mockResponse.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 50), () {
        _handleRawData(mockResponse);
      });
    }
  }

  // ==========================================
  // 6. MACHINE LEARNING INTEGRATION (NEW)
  // ==========================================

  void startMLAnalysisEngine() {
    if (!isConnected) return;
    print("Starting Background ML Analysis...");
    
    // Send a snapshot to the Python server every 10 seconds
    _mlAnalysisTimer?.cancel();
    _mlAnalysisTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      await _runAIAnalysis();
    });
  }

  void stopMLAnalysisEngine() {
    _mlAnalysisTimer?.cancel();
    print("Stopped Background ML Analysis.");
  }

  Future<void> _runAIAnalysis() async {
    // ⚠️ IMPORTANT: Verify this IP matches your FastAPI laptop IP!
    final url = Uri.parse('http://192.168.100.121:8000/analyze'); 

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "rpm": currentRpm,
          "speed": currentSpeed,
          "load": currentLoad,
          "coolant": currentCoolant,
          "intake": currentIntake,
          "throttle": currentThrottle
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        bool isAnomaly = result['is_anomaly'];
        List<dynamic> warnings = result['warnings'];
        String diagnosis = result['ai_diagnosis'];
        int score = result['behavior_score'] ?? 100;

        if (isAnomaly || warnings.isNotEmpty) {
          print("🚨 ML ANOMALY DETECTED: $diagnosis");
          // Broadcast to the UI stream so your frontend can show a popup!
          _obdDataController.add({
            'type': 'ML_ALERT', 
            'message': diagnosis,
            'score': score
          });
        } else {
          print("✅ ML Check Passed. Engine Health Score: $score");
          // You can also broadcast healthy scores to update a UI gauge
          _obdDataController.add({
            'type': 'ML_HEALTH',
            'score': score
          });
        }
      }
    } catch (e) {
      print("ML Analysis Connection Error: $e");
    }
  }
}