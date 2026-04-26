import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math'; // Added for the simulator
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class OBDService {
  BluetoothConnection? connection;
  bool isConnected = false;
  bool isSimulating = false; // Tracks if we are in fake mode
  
  final StreamController<Map<String, dynamic>> _obdDataController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get obdDataStream => _obdDataController.stream;

  String _responseBuffer = "";
  
  // Simulation Variables
  Timer? _simulationTimer;
  int _simRpm = 800; // Engine idle
  int _simSpeed = 0;
  bool _isAccelerating = true;

  // ==========================================
  // 1. THE SIMULATOR MODE
  // ==========================================
  Future<bool> startSimulation() async {
    isSimulating = true;
    isConnected = true;
    
    // Fake a 1-second connection delay
    await Future.delayed(const Duration(seconds: 1));
    print("Simulation Mode Started");

    // Push fake data every 500 milliseconds
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      final random = Random();

      // Fake Engine Logic
      if (_isAccelerating) {
        _simRpm += random.nextInt(300) + 100; // Rev up
        if (_simRpm > 2500) _simSpeed += random.nextInt(4) + 1; // Speed increases as RPM gets high
        if (_simRpm > 4500) _isAccelerating = false; // "Shift gears" or let off gas
      } else {
        _simRpm -= random.nextInt(400) + 100; // Revs drop
        if (_simRpm < 900) {
          _simRpm = random.nextInt(200) + 700; // Settle at idle
          _isAccelerating = true; // Start accelerating again
        }
      }

      // Push to the exact same stream the real Bluetooth uses!
      _obdDataController.add({'type': 'RPM', 'value': _simRpm});
      _obdDataController.add({'type': 'SPEED', 'value': _simSpeed});
    });

    return true;
  }

  // ==========================================
  // 2. REAL BLUETOOTH CONNECTION
  // ==========================================
  Future<bool> connectToDevice(BluetoothDevice device) async {
    isSimulating = false;
    try {
      connection = await BluetoothConnection.toAddress(device.address);
      isConnected = true;
      
      connection!.input!.listen(_onDataReceived).onDone(() {
        isConnected = false;
      });

      await _initializeELM327();
      return true;
    } catch (e) {
      isConnected = false;
      return false;
    }
  }

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
    // Only send real commands if we aren't simulating
    if (!isSimulating && connection != null && connection!.isConnected) {
      connection!.output.add(ascii.encode(command));
      await connection!.output.allSent;
    }
  }

  void _onDataReceived(Uint8List data) {
    if (isSimulating) return; // Ignore real data if simulating
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

  // ==========================================
  // 3. DISCONNECT LOGIC
  // ==========================================
  void disconnect() {
    _simulationTimer?.cancel(); // Stop the fake engine
    if (connection != null && connection!.isConnected) {
      connection?.close();
    }
    isConnected = false;
    isSimulating = false;
  }
}