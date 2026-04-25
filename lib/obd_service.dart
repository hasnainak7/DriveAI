import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class OBDService {
  BluetoothConnection? connection;
  bool isConnected = false;

  // 1. Connect to the ELM327 Device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      connection = await BluetoothConnection.toAddress(device.address);
      isConnected = true;
      print('Connected to the car device!');
      
      // Once connected, we must initialize the ELM327 adapter
      await _initializeELM327();
      return true;
    } catch (e) {
      print('Cannot connect, exception occurred: $e');
      isConnected = false;
      return false;
    }
  }

  // 2. The Initial Handshake (AT Commands)
  Future<void> _initializeELM327() async {
    if (!isConnected) return;
    
    // ATZ: Reset the adapter
    await sendCommand('ATZ\r');
    await Future.delayed(const Duration(seconds: 1));
    
    // ATE0: Echo off (so it doesn't repeat our commands back to us)
    await sendCommand('ATE0\r');
    await Future.delayed(const Duration(milliseconds: 500));
    
    // ATSP0: Auto-detect the OBD2 protocol for the specific car
    await sendCommand('ATSP0\r');
    await Future.delayed(const Duration(milliseconds: 500));
    
    print("ELM327 Initialized and ready for data!");
  }

  // 3. Helper to send commands and read responses
  Future<void> sendCommand(String command) async {
    if (connection != null && connection!.isConnected) {
      connection!.output.add(ascii.encode(command));
      await connection!.output.allSent;
    }
  }

  // 4. Disconnect safely
  void disconnect() {
    if (isConnected) {
      connection?.close();
      isConnected = false;
    }
  }
}