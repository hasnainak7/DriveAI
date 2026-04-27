import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math'; 
import 'dart:io'; // NEW: Imported for Wi-Fi Sockets
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class OBDService {
  BluetoothConnection? btConnection;
  Socket? wifiSocket; // NEW: The TCP Socket for Wi-Fi
  bool isConnected = false;
  bool isSimulating = false; 
  
  final StreamController<Map<String, dynamic>> _obdDataController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get obdDataStream => _obdDataController.stream;

  String _responseBuffer = "";
  
  // Simulation Variables
  Timer? _simulationTimer;
  int _simRpm = 800; 
  int _simSpeed = 0;
  bool _isAccelerating = true;

  // ==========================================
  // 1. BLUETOOTH CONNECTION
  // ==========================================
  Future<bool> connectToBluetooth(BluetoothDevice device) async {
    disconnect(); // Ensure previous connections are closed
    try {
      btConnection = await BluetoothConnection.toAddress(device.address);
      isConnected = true;
      
      btConnection!.input!.listen(_onDataReceived).onDone(() {
        isConnected = false;
      });

      await _initializeELM327();
      return true;
    } catch (e) {
      isConnected = false;
      return false;
    }
  }

  // ==========================================
  // 2. WI-FI CONNECTION (TCP SOCKET)
  // ==========================================
  Future<bool> connectToWiFi(String ip, int port) async {
    disconnect(); // Ensure previous connections are closed
    try {
      // Connect to the OBD2 Wi-Fi Hotspot (Usually 192.168.0.10:35000)
      wifiSocket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      isConnected = true;
      
      // Listen to the raw TCP stream
      wifiSocket!.listen(_onDataReceived).onDone(() {
        isConnected = false;
      });

      await _initializeELM327();
      return true;
    } catch (e) {
      isConnected = false;
      return false;
    }
  }

  // ==========================================
  // 3. SIMULATOR
  // ==========================================
  Future<bool> startSimulation() async {
    disconnect();
    isSimulating = true;
    isConnected = true;
    
    await Future.delayed(const Duration(seconds: 1));

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      final random = Random();
      if (_isAccelerating) {
        _simRpm += random.nextInt(300) + 100;
        if (_simRpm > 2500) _simSpeed += random.nextInt(4) + 1;
        if (_simRpm > 4500) _isAccelerating = false;
      } else {
        _simRpm -= random.nextInt(400) + 100;
        if (_simRpm < 900) {
          _simRpm = random.nextInt(200) + 700;
          _isAccelerating = true;
        }
      }
      _obdDataController.add({'type': 'RPM', 'value': _simRpm});
      _obdDataController.add({'type': 'SPEED', 'value': _simSpeed});
    });

    return true;
  }

  // ==========================================
  // 4. CORE LOGIC (Init, Send, Parse)
  // ==========================================
  Future<void> _initializeELM327() async {
    if (!isConnected || isSimulating) return;
    await sendCommand('ATZ\r');
    await Future.delayed(const Duration(seconds: 1));
    await sendCommand('ATE0\r');
    await Future.delayed(const Duration(milliseconds: 500));
    await sendCommand('ATSP0\r');
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> sendCommand(String command) async {
    if (isSimulating) return;
    
    // Route command via Bluetooth OR Wi-Fi depending on what is active
    if (btConnection != null && btConnection!.isConnected) {
      btConnection!.output.add(ascii.encode(command));
      await btConnection!.output.allSent;
    } else if (wifiSocket != null) {
      wifiSocket!.add(ascii.encode(command));
      await wifiSocket!.flush();
    }
  }

  void _onDataReceived(Uint8List data) {
    if (isSimulating) return; 
    String chunk = ascii.decode(data);
    _responseBuffer += chunk;

    if (_responseBuffer.contains('>')) {
      _processObdResponse(_responseBuffer);
      _responseBuffer = "";
    }
  }

  void _processObdResponse(String rawData) {
    String cleanData = rawData.replaceAll(RegExp(r'[\r\n\s>]'), '');
    try {
      if (cleanData.contains('410C') && cleanData.length >= 8) {
        int index = cleanData.indexOf('410C');
        int a = int.parse(cleanData.substring(index + 4, index + 6), radix: 16);
        int b = int.parse(cleanData.substring(index + 6, index + 8), radix: 16);
        _obdDataController.add({'type': 'RPM', 'value': ((a * 256) + b) ~/ 4});
      }
      if (cleanData.contains('410D') && cleanData.length >= 6) {
        int index = cleanData.indexOf('410D');
        _obdDataController.add({'type': 'SPEED', 'value': int.parse(cleanData.substring(index + 4, index + 6), radix: 16)});
      }
    } catch (e) {
      print("Parser error");
    }
  }

  void disconnect() {
    _simulationTimer?.cancel();
    
    btConnection?.close();
    btConnection = null;
    
    wifiSocket?.close();
    wifiSocket = null;
    
    isConnected = false;
    isSimulating = false;
  }
}