import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'dart:io';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class OBDService {
  BluetoothConnection? btConnection;
  Socket? wifiSocket;
  bool isConnected = false;
  bool isSimulating = false;

  final StreamController<Map<String, dynamic>> _obdDataController =
      StreamController.broadcast();
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
    disconnect();
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
    disconnect();
    try {
      wifiSocket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 5),
      );
      isConnected = true;

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
  // 3. SIMULATOR (6 Sensors + DTCs)
  // ==========================================
  Future<bool> startSimulation() async {
    disconnect();
    isSimulating = true;
    isConnected = true;

    await Future.delayed(const Duration(seconds: 1));

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
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
      _obdDataController.add({
        'type': 'LOAD',
        'value': _isAccelerating
            ? 65 + random.nextInt(20)
            : 15 + random.nextInt(10),
      });
      _obdDataController.add({
        'type': 'COOLANT',
        'value': 88 + random.nextInt(4),
      });
      _obdDataController.add({
        'type': 'INTAKE',
        'value': 35 + random.nextInt(5),
      });
      _obdDataController.add({
        'type': 'THROTTLE',
        'value': _isAccelerating ? 40 + random.nextInt(40) : 0,
      });
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
        _obdDataController.add({
          'type': 'SPEED',
          'value': int.parse(
            cleanData.substring(index + 4, index + 6),
            radix: 16,
          ),
        });
      }
      if (cleanData.contains('4104') && cleanData.length >= 6) {
        int index = cleanData.indexOf('4104');
        int a = int.parse(cleanData.substring(index + 4, index + 6), radix: 16);
        _obdDataController.add({'type': 'LOAD', 'value': (a * 100) ~/ 255});
      }
      if (cleanData.contains('4105') && cleanData.length >= 6) {
        int index = cleanData.indexOf('4105');
        int a = int.parse(cleanData.substring(index + 4, index + 6), radix: 16);
        _obdDataController.add({'type': 'COOLANT', 'value': a - 40});
      }
      if (cleanData.contains('410F') && cleanData.length >= 6) {
        int index = cleanData.indexOf('410F');
        int a = int.parse(cleanData.substring(index + 4, index + 6), radix: 16);
        _obdDataController.add({'type': 'INTAKE', 'value': a - 40});
      }
      if (cleanData.contains('4111') && cleanData.length >= 6) {
        int index = cleanData.indexOf('4111');
        int a = int.parse(cleanData.substring(index + 4, index + 6), radix: 16);
        _obdDataController.add({'type': 'THROTTLE', 'value': (a * 100) ~/ 255});
      }

      // Parse DTC Responses (Mode 43)
      if (cleanData.contains('43') && cleanData.length >= 6) {
        int index = cleanData.indexOf('43');
        String dtcData = cleanData.substring(index + 2);
        List<String> foundCodes = [];

        for (int i = 0; i < dtcData.length - 3; i += 4) {
          String codeA = dtcData.substring(i, i + 2);
          String codeB = dtcData.substring(i + 2, i + 4);

          if (codeA != "00" && codeB != "00") {
            foundCodes.add(_decodeDtcHex(codeA, codeB));
          }
        }
        _obdDataController.add({'type': 'DTC', 'codes': foundCodes});
      }

      // Parse Clear Command Success (Mode 44)
      if (cleanData.contains('44')) {
        _obdDataController.add({'type': 'DTC_CLEARED'});
      }
    } catch (e) {
      print("Parser error");
    }
  }

  // ==========================================
  // 5. DIAGNOSTIC TROUBLE CODES (DTC)
  // ==========================================
  Future<void> requestDTCs() async {
    if (isSimulating) {
      await Future.delayed(const Duration(seconds: 1));
      _obdDataController.add({
        'type': 'DTC',
        'codes': ['P0301', 'P0420'],
      });
      return;
    }
    await sendCommand('03\r');
  }

  Future<void> clearDTCs() async {
    if (isSimulating) {
      await Future.delayed(const Duration(seconds: 1));
      _obdDataController.add({'type': 'DTC_CLEARED'});
      return;
    }
    await sendCommand('04\r');
  }

  String _decodeDtcHex(String hexA, String hexB) {
    if (hexA.isEmpty || hexB.isEmpty) return "";

    int a = int.parse(hexA, radix: 16);
    int b = int.parse(hexB, radix: 16);

    String system;
    switch ((a & 0xC0) >> 6) {
      case 0:
        system = "P";
        break;
      case 1:
        system = "C";
        break;
      case 2:
        system = "B";
        break;
      case 3:
        system = "U";
        break;
      default:
        system = "P";
    }

    int category = (a & 0x30) >> 4;
    String thirdChar = (a & 0x0F).toRadixString(16).toUpperCase();
    String fourthFifthChar = hexB.toUpperCase().padLeft(2, '0');

    return "$system$category$thirdChar$fourthFifthChar";
  }

  // ==========================================
  // 6. DISCONNECT LOGIC
  // ==========================================
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
