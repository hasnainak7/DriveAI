import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class OBDService {
  BluetoothConnection? connection;
  bool isConnected = false;
  
  // A stream controller to broadcast clean data to your UI
  final StreamController<Map<String, dynamic>> _obdDataController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get obdDataStream => _obdDataController.stream;

  String _responseBuffer = "";

  // 1. Connect to the ELM327 Device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      connection = await BluetoothConnection.toAddress(device.address);
      isConnected = true;
      
      // Start listening to the car's replies immediately
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

  // 2. The Initialization
  Future<void> _initializeELM327() async {
    if (!isConnected) return;
    await sendCommand('ATZ\r');
    await Future.delayed(const Duration(seconds: 1));
    await sendCommand('ATE0\r');
    await Future.delayed(const Duration(milliseconds: 500));
    await sendCommand('ATSP0\r');
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // 3. Send Commands
  Future<void> sendCommand(String command) async {
    if (connection != null && connection!.isConnected) {
      connection!.output.add(ascii.encode(command));
      await connection!.output.allSent;
    }
  }

  // 4. The Listener & Hex Parser (The Magic Happens Here)
  void _onDataReceived(Uint8List data) {
    String chunk = ascii.decode(data);
    _responseBuffer += chunk;

    // ELM327 messages always end with a '>' prompt
    if (_responseBuffer.contains('>')) {
      _processObdResponse(_responseBuffer);
      _responseBuffer = ""; // Clear buffer for the next message
    }
  }

  void _processObdResponse(String rawData) {
    // Clean up the string (remove spaces, newlines, and the '>' symbol)
    String cleanData = rawData.replaceAll(RegExp(r'[\r\n\s>]'), '');

    try {
      // Parse Engine RPM (010C returns 410C)
      if (cleanData.contains('410C') && cleanData.length >= 8) {
        int index = cleanData.indexOf('410C');
        String hexA = cleanData.substring(index + 4, index + 6);
        String hexB = cleanData.substring(index + 6, index + 8);
        int a = int.parse(hexA, radix: 16);
        int b = int.parse(hexB, radix: 16);
        int rpm = ((a * 256) + b) ~/ 4;
        
        _obdDataController.add({'type': 'RPM', 'value': rpm});
      }
      
      // Parse Vehicle Speed (010D returns 410D)
      if (cleanData.contains('410D') && cleanData.length >= 6) {
        int index = cleanData.indexOf('410D');
        String hexA = cleanData.substring(index + 4, index + 6);
        int speed = int.parse(hexA, radix: 16);
        
        _obdDataController.add({'type': 'SPEED', 'value': speed});
      }
    } catch (e) {
      print("Parser error on data: $cleanData");
    }
  }

  void disconnect() {
    if (isConnected) {
      connection?.close();
      isConnected = false;
    }
    _obdDataController.close();
  }
}