// import 'dart:async';
// import 'dart:convert';
// import 'dart:typed_data';
// import 'dart:math';
// import 'dart:io';
// import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

// class OBDService {
//   BluetoothConnection? btConnection;
//   Socket? wifiSocket;
//   bool isConnected = false;
//   bool isSimulating = false;

//   final StreamController<Map<String, dynamic>> _obdDataController =
//       StreamController.broadcast();
//   Stream<Map<String, dynamic>> get obdDataStream => _obdDataController.stream;

//   String _responseBuffer = "";

//   // Simulation Variables
//   Timer? _simulationTimer;
//   int _simRpm = 800;
//   int _simSpeed = 0;
//   bool _isAccelerating = true;

//   // ==========================================
//   // 1. BLUETOOTH CONNECTION
//   // ==========================================
//   Future<bool> connectToBluetooth(BluetoothDevice device) async {
//     disconnect();
//     try {
//       btConnection = await BluetoothConnection.toAddress(device.address);
//       isConnected = true;

//       btConnection!.input!.listen(_onDataReceived).onDone(() {
//         isConnected = false;
//       });

//       await _initializeELM327();
//       return true;
//     } catch (e) {
//       isConnected = false;
//       return false;
//     }
//   }

//   // ==========================================
//   // 2. WI-FI CONNECTION (TCP SOCKET)
//   // ==========================================
//   Future<bool> connectToWiFi(String ip, int port) async {
//     disconnect();
//     try {
//       wifiSocket = await Socket.connect(
//         ip,
//         port,
//         timeout: const Duration(seconds: 5),
//       );
//       isConnected = true;

//       wifiSocket!.listen(_onDataReceived).onDone(() {
//         isConnected = false;
//       });

//       await _initializeELM327();
//       return true;
//     } catch (e) {
//       isConnected = false;
//       return false;
//     }
//   }

//   // ==========================================
//   // 3. SIMULATOR (6 Sensors + DTCs)
//   // ==========================================
//   Future<bool> startSimulation() async {
//     disconnect();
//     isSimulating = true;
//     isConnected = true;

//     await Future.delayed(const Duration(seconds: 1));

//     _simulationTimer = Timer.periodic(const Duration(milliseconds: 500), (
//       timer,
//     ) {
//       final random = Random();

//       if (_isAccelerating) {
//         _simRpm += random.nextInt(300) + 100;
//         if (_simRpm > 2500) _simSpeed += random.nextInt(4) + 1;
//         if (_simRpm > 4500) _isAccelerating = false;
//       } else {
//         _simRpm -= random.nextInt(400) + 100;
//         if (_simRpm < 900) {
//           _simRpm = random.nextInt(200) + 700;
//           _isAccelerating = true;
//         }
//       }

//       _obdDataController.add({'type': 'RPM', 'value': _simRpm});
//       _obdDataController.add({'type': 'SPEED', 'value': _simSpeed});
//       _obdDataController.add({
//         'type': 'LOAD',
//         'value': _isAccelerating
//             ? 65 + random.nextInt(20)
//             : 15 + random.nextInt(10),
//       });
//       _obdDataController.add({
//         'type': 'COOLANT',
//         'value': 88 + random.nextInt(4),
//       });
//       _obdDataController.add({
//         'type': 'INTAKE',
//         'value': 35 + random.nextInt(5),
//       });
//       _obdDataController.add({
//         'type': 'THROTTLE',
//         'value': _isAccelerating ? 40 + random.nextInt(40) : 0,
//       });
//     });

//     return true;
//   }

//   // ==========================================
//   // 4. CORE LOGIC (Init, Send, Parse)
//   // ==========================================
//   Future<void> _initializeELM327() async {
//     if (!isConnected || isSimulating) return;
//     await sendCommand('ATZ\r');
//     await Future.delayed(const Duration(seconds: 1));
//     await sendCommand('ATE0\r');
//     await Future.delayed(const Duration(milliseconds: 500));
//     await sendCommand('ATSP0\r');
//     await Future.delayed(const Duration(milliseconds: 500));
//   }

//   Future<void> sendCommand(String command) async {
//     if (isSimulating) return;

//     if (btConnection != null && btConnection!.isConnected) {
//       btConnection!.output.add(ascii.encode(command));
//       await btConnection!.output.allSent;
//     } else if (wifiSocket != null) {
//       wifiSocket!.add(ascii.encode(command));
//       await wifiSocket!.flush();
//     }
//   }

//   void _onDataReceived(Uint8List data) {
//     if (isSimulating) return;
//     String chunk = ascii.decode(data);
//     _responseBuffer += chunk;

//     if (_responseBuffer.contains('>')) {
//       _processObdResponse(_responseBuffer);
//       _responseBuffer = "";
//     }
//   }

//   void _processObdResponse(String rawData) {
//     String cleanData = rawData.replaceAll(RegExp(r'[\r\n\s>]'), '');
//     try {
//       if (cleanData.contains('410C') && cleanData.length >= 8) {
//         int index = cleanData.indexOf('410C');
//         int a = int.parse(cleanData.substring(index + 4, index + 6), radix: 16);
//         int b = int.parse(cleanData.substring(index + 6, index + 8), radix: 16);
//         _obdDataController.add({'type': 'RPM', 'value': ((a * 256) + b) ~/ 4});
//       }
//       if (cleanData.contains('410D') && cleanData.length >= 6) {
//         int index = cleanData.indexOf('410D');
//         _obdDataController.add({
//           'type': 'SPEED',
//           'value': int.parse(
//             cleanData.substring(index + 4, index + 6),
//             radix: 16,
//           ),
//         });
//       }
//       if (cleanData.contains('4104') && cleanData.length >= 6) {
//         int index = cleanData.indexOf('4104');
//         int a = int.parse(cleanData.substring(index + 4, index + 6), radix: 16);
//         _obdDataController.add({'type': 'LOAD', 'value': (a * 100) ~/ 255});
//       }
//       if (cleanData.contains('4105') && cleanData.length >= 6) {
//         int index = cleanData.indexOf('4105');
//         int a = int.parse(cleanData.substring(index + 4, index + 6), radix: 16);
//         _obdDataController.add({'type': 'COOLANT', 'value': a - 40});
//       }
//       if (cleanData.contains('410F') && cleanData.length >= 6) {
//         int index = cleanData.indexOf('410F');
//         int a = int.parse(cleanData.substring(index + 4, index + 6), radix: 16);
//         _obdDataController.add({'type': 'INTAKE', 'value': a - 40});
//       }
//       if (cleanData.contains('4111') && cleanData.length >= 6) {
//         int index = cleanData.indexOf('4111');
//         int a = int.parse(cleanData.substring(index + 4, index + 6), radix: 16);
//         _obdDataController.add({'type': 'THROTTLE', 'value': (a * 100) ~/ 255});
//       }

//       // Parse DTC Responses (Mode 43)
//       if (cleanData.contains('43') && cleanData.length >= 6) {
//         int index = cleanData.indexOf('43');
//         String dtcData = cleanData.substring(index + 2);
//         List<String> foundCodes = [];

//         for (int i = 0; i < dtcData.length - 3; i += 4) {
//           String codeA = dtcData.substring(i, i + 2);
//           String codeB = dtcData.substring(i + 2, i + 4);

//           if (codeA != "00" && codeB != "00") {
//             foundCodes.add(_decodeDtcHex(codeA, codeB));
//           }
//         }
//         _obdDataController.add({'type': 'DTC', 'codes': foundCodes});
//       }

//       // Parse Clear Command Success (Mode 44)
//       if (cleanData.contains('44')) {
//         _obdDataController.add({'type': 'DTC_CLEARED'});
//       }
//     } catch (e) {
//       print("Parser error");
//     }
//   }

//   // ==========================================
//   // 5. DIAGNOSTIC TROUBLE CODES (DTC)
//   // ==========================================
//   Future<void> requestDTCs() async {
//     if (isSimulating) {
//       await Future.delayed(const Duration(seconds: 1));
//       _obdDataController.add({
//         'type': 'DTC',
//         'codes': ['P0301', 'P0420'],
//       });
//       return;
//     }
//     await sendCommand('03\r');
//   }

//   Future<void> clearDTCs() async {
//     if (isSimulating) {
//       await Future.delayed(const Duration(seconds: 1));
//       _obdDataController.add({'type': 'DTC_CLEARED'});
//       return;
//     }
//     await sendCommand('04\r');
//   }

//   String _decodeDtcHex(String hexA, String hexB) {
//     if (hexA.isEmpty || hexB.isEmpty) return "";

//     int a = int.parse(hexA, radix: 16);
//     int b = int.parse(hexB, radix: 16);

//     String system;
//     switch ((a & 0xC0) >> 6) {
//       case 0:
//         system = "P";
//         break;
//       case 1:
//         system = "C";
//         break;
//       case 2:
//         system = "B";
//         break;
//       case 3:
//         system = "U";
//         break;
//       default:
//         system = "P";
//     }

//     int category = (a & 0x30) >> 4;
//     String thirdChar = (a & 0x0F).toRadixString(16).toUpperCase();
//     String fourthFifthChar = hexB.toUpperCase().padLeft(2, '0');

//     return "$system$category$thirdChar$fourthFifthChar";
//   }

//   // ==========================================
//   // 6. DISCONNECT LOGIC
//   // ==========================================
//   void disconnect() {
//     _simulationTimer?.cancel();

//     btConnection?.close();
//     btConnection = null;

//     wifiSocket?.close();
//     wifiSocket = null;

//     isConnected = false;
//     isSimulating = false;
//   }
// }



import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

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
        _obdDataController.add({'type': 'RPM', 'value': ((a * 256) + b) ~/ 4});
      }
    }
    
    // Vehicle Speed (PID 0D) -> Formula: A
    else if (response.startsWith("41 0D") || response.startsWith("410D")) {
      List<String> parts = _splitHex(response, "41 0D");
      if (parts.isNotEmpty) {
        int a = int.parse(parts[0], radix: 16);
        _obdDataController.add({'type': 'SPEED', 'value': a});
      }
    }
    
    // Engine Load (PID 04) -> Formula: A * 100 / 255
    else if (response.startsWith("41 04") || response.startsWith("4104")) {
      List<String> parts = _splitHex(response, "41 04");
      if (parts.isNotEmpty) {
        int a = int.parse(parts[0], radix: 16);
        _obdDataController.add({'type': 'LOAD', 'value': (a * 100) ~/ 255});
      }
    }
    
    // Coolant Temp (PID 05) -> Formula: A - 40
    else if (response.startsWith("41 05") || response.startsWith("4105")) {
      List<String> parts = _splitHex(response, "41 05");
      if (parts.isNotEmpty) {
        int a = int.parse(parts[0], radix: 16);
        _obdDataController.add({'type': 'COOLANT', 'value': a - 40});
      }
    }

    // Intake Air Temp (PID 0F) -> Formula: A - 40
    else if (response.startsWith("41 0F") || response.startsWith("410F")) {
      List<String> parts = _splitHex(response, "41 0F");
      if (parts.isNotEmpty) {
        int a = int.parse(parts[0], radix: 16);
        _obdDataController.add({'type': 'INTAKE', 'value': a - 40});
      }
    }

    // Throttle Position (PID 11) -> Formula: A * 100 / 255
    else if (response.startsWith("41 11") || response.startsWith("4111")) {
      List<String> parts = _splitHex(response, "41 11");
      if (parts.isNotEmpty) {
        int a = int.parse(parts[0], radix: 16);
        _obdDataController.add({'type': 'THROTTLE', 'value': (a * 100) ~/ 255});
      }
    }

    // ---> NEW: Distance Traveled Since Codes Cleared (PID 31) <---
    // Formula: (A * 256) + B (Returns value in kilometers)
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

  // Helper to clean up ELM327 hex strings whether they have spaces or not
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
    // A simplified DTC parser for FYP scope.
    // Real DTC parsing requires bitwise operations to extract P, C, B, U prefixes.
    String cleanResponse = response.replaceAll(' ', '');
    if (cleanResponse.length > 2) {
      String data = cleanResponse.substring(2);
      List<String> codes = [];
      for (int i = 0; i < data.length; i += 4) {
        if (i + 4 <= data.length) {
          String rawHex = data.substring(i, i + 4);
          if (rawHex != "0000") {
            // Very basic prefix assumption for testing (Assume Powertrain 'P')
            codes.add("P${rawHex.substring(1)}"); 
          }
        }
      }
      _obdDataController.add({'type': 'DTC', 'codes': codes});
    }
  }

  // ==========================================
  // 5. DEVELOPER SIMULATION ENGINE
  // ==========================================

  void _generateSimulatedResponse(String command) {
    String mockResponse = "";
    String cmd = command.replaceAll('\r', '');

    if (cmd == "010C") {
      // Fake RPM: ~2500 RPM (Hex: 41 0C 27 10 -> (39*256 + 16)/4 = 2500)
      mockResponse = "41 0C 27 10>";
    } else if (cmd == "010D") {
      // Fake Speed: 60 km/h (Hex 3C)
      mockResponse = "41 0D 3C>";
    } else if (cmd == "0104") {
      // Fake Load: ~40% (Hex 66)
      mockResponse = "41 04 66>";
    } else if (cmd == "0105") {
      // Fake Coolant: 90C (Hex 82 -> 130 - 40 = 90)
      mockResponse = "41 05 82>";
    } else if (cmd == "010F") {
      // Fake Intake: 35C (Hex 4B -> 75 - 40 = 35)
      mockResponse = "41 0F 4B>";
    } else if (cmd == "0111") {
      // Fake Throttle: ~25% (Hex 40)
      mockResponse = "41 11 40>";
    } else if (cmd == "0131") {
      // Fake Distance Since Codes Cleared: 5120 km (Hex 14 00)
      mockResponse = "41 31 14 00>";
    }

    if (mockResponse.isNotEmpty) {
      // Simulate hardware delay
      Future.delayed(const Duration(milliseconds: 50), () {
        _handleRawData(mockResponse);
      });
    }
  }
}