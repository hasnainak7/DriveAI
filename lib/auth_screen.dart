import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
// Your custom file imports
import 'main.dart';
import 'obd_service.dart';
import 'garage_screen.dart';
import 'dtc_screen.dart';
import 'safety_screen.dart';
import 'maintenance_screen.dart';
import 'safety_engine.dart';
import 'trip_screen.dart';
import 'mechanic_portal_screen.dart';

// ==========================================
// 1. DATA MODELS
// ==========================================
class SensorConfig {
  final String id;
  final String name;
  final String unit;
  final double min;
  final double max;
  final Color color;

  SensorConfig({
    required this.id,
    required this.name,
    required this.unit,
    required this.min,
    required this.max,
    required this.color,
  });
}

final List<SensorConfig> availableSensors = [
  SensorConfig(
    id: 'RPM',
    name: 'Engine Speed',
    unit: 'RPM',
    min: 0,
    max: 8000,
    color: Colors.cyan,
  ),
  SensorConfig(
    id: 'SPEED',
    name: 'Vehicle Speed',
    unit: 'km/h',
    min: 0,
    max: 240,
    color: Colors.greenAccent,
  ),
  SensorConfig(
    id: 'LOAD',
    name: 'Engine Load',
    unit: '%',
    min: 0,
    max: 100,
    color: Colors.orangeAccent,
  ),
  SensorConfig(
    id: 'COOLANT',
    name: 'Coolant Temp',
    unit: '°C',
    min: -40,
    max: 215,
    color: Colors.redAccent,
  ),
  SensorConfig(
    id: 'INTAKE',
    name: 'Intake Temp',
    unit: '°C',
    min: -40,
    max: 215,
    color: Colors.blueAccent,
  ),
  SensorConfig(
    id: 'THROTTLE',
    name: 'Throttle Pos',
    unit: '%',
    min: 0,
    max: 100,
    color: Colors.purpleAccent,
  ),
];



// ==========================================
// 2. THE AUTHENTICATION SCREEN
// ==========================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  String _selectedRole = 'driver'; // Default role

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // Sign Up with Role Metadata
        await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {
            'full_name': _usernameController.text.trim(),
            'role': _selectedRole, // 'driver' or 'mechanic'
          },
        );
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isLogin ? 'LOGIN' : 'REGISTER',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 40),

                  if (!_isLogin) ...[
                    const Text(
                      'I AM A...',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    // ROLE SELECTION UI
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedRole = 'driver'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedRole == 'driver'
                                    ? Colors.cyan
                                    : const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _selectedRole == 'driver'
                                      ? Colors.cyan
                                      : Colors.white24,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'DRIVER',
                                  style: TextStyle(
                                    color: _selectedRole == 'driver'
                                        ? Colors.black
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedRole = 'mechanic'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedRole == 'mechanic'
                                    ? Colors.cyan
                                    : const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _selectedRole == 'mechanic'
                                      ? Colors.cyan
                                      : Colors.white24,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'MECHANIC',
                                  style: TextStyle(
                                    color: _selectedRole == 'mechanic'
                                        ? Colors.black
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'USERNAME',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Enter username',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter a username' : null,
                    ),
                    const SizedBox(height: 20),
                  ],

                  const Text('EMAIL', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Enter email',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    // ---> NEW REGEX VALIDATION APPLIED HERE <---
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      
                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      
                      if (!emailRegex.hasMatch(value.trim())) {
                        return 'Enter a valid email (e.g., name@domain.com)';
                      }
                      
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'PASSWORD',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Enter password',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) =>
                        value!.length < 6 ? 'Password must be 6+ chars' : null,
                  ),
                  const SizedBox(height: 30),

                  _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.cyan),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _submitForm,
                          child: Text(
                            _isLogin ? 'LOGIN' : 'REGISTER',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: () => setState(() {
                      _isLogin = !_isLogin;
                      _formKey.currentState?.reset();
                    }),
                    child: RichText(
                      text: TextSpan(
                        text: _isLogin
                            ? "Don't have an account? "
                            : "Already have an account? ",
                        style: const TextStyle(color: Colors.white),
                        children: [
                          TextSpan(
                            text: _isLogin ? 'Signup' : 'Login',
                            style: const TextStyle(
                              color: Colors.cyan,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. THE NEW HOME HUB SCREEN
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Core Services
  final OBDService _obdService = OBDService();
  Map<String, dynamic>? _activeVehicle;
  RealtimeChannel? _telemetryChannel;

  // State Variables
  bool _isDemoMode = false;
  bool _isConnected = false;
  bool _isPollingData = false;
  Timer? _dbLogTimer;
  bool _hasTriggeredMaintenanceAlert = false;

  // Background Data Tracking
  int _currentRpm = 0, _currentSpeed = 0, _engineLoad = 0;
  int _coolantTemp = 0, _intakeTemp = 0, _throttlePos = 0, _currentDistance = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();

    // ---> START GLOBAL SAFETY ENGINE <---
    SafetyEngine().initializeEngine().then((_) {
      SafetyEngine().startMonitoring();
    });

    // Master Background Listener
    _obdService.obdDataStream.listen((data) {
      if (mounted) {
        // ---> 1. THE ML ALERT LISTENER <---
        if (data['type'] == 'ML_ALERT') {
          _showAIWarningPopup(data['message'], data['score']);
        }

        if (data['type'] == 'RPM') _currentRpm = data['value'];
        if (data['type'] == 'SPEED') _currentSpeed = data['value'];
        if (data['type'] == 'LOAD') _engineLoad = data['value'];
        if (data['type'] == 'COOLANT') _coolantTemp = data['value'];
        if (data['type'] == 'INTAKE') _intakeTemp = data['value'];
        if (data['type'] == 'THROTTLE') _throttlePos = data['value'];

        if (data['type'] == 'DISTANCE') {
          _currentDistance = data['value'];
          _checkMaintenanceStatus(_currentDistance);
        }

        // Live Logging to Supabase
        if (_isConnected && _telemetryChannel != null) {
          _telemetryChannel!.sendBroadcastMessage(
            event: 'live_data',
            payload: {
              'vehicle_id': _activeVehicle!['id'],
              'rpm': _currentRpm,
              'speed': _currentSpeed,
              'load': _engineLoad,
              'coolant': _coolantTemp,
              'intake': _intakeTemp,
              'throttle': _throttlePos,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
      }
    });
  }

  // ---> 2. THE ML POPUP UI <---
  void _showAIWarningPopup(String diagnosis, int score) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.memory, color: Colors.white, size: 30),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'AI PREDICTIVE ALERT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Engine Health Score Drop: $score/100',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              diagnosis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'ACKNOWLEDGE',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
  }

  void _setupRealtimeChannel() {
    if (_activeVehicle == null) return;
    final channelName = 'telemetry_${_activeVehicle!['id']}';
    _telemetryChannel = supabase.channel(channelName);
    _telemetryChannel!.subscribe();
  }

  void _startDatabaseLogging() {
    _dbLogTimer?.cancel();
    _dbLogTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isConnected || _activeVehicle == null) return;
      try {
        await supabase.from('telemetry_logs').insert({
          'vehicle_id': _activeVehicle!['id'],
          'rpm': _currentRpm,
          'speed': _currentSpeed,
          'engine_load': _engineLoad,
          'coolant_temp': _coolantTemp,
          'intake_temp': _intakeTemp,
          'throttle_pos': _throttlePos,
        });
      } catch (e) {
        print("Failed to log telemetry: $e");
      }
    });
  }

  void _startPollingData() async {
    _isPollingData = true;
    while (_isConnected && _isPollingData) {
      if (!_obdService.isConnected) break;
      await _obdService.sendCommand('010C\r');
      await Future.delayed(const Duration(milliseconds: 150));
      await _obdService.sendCommand('010D\r');
      await Future.delayed(const Duration(milliseconds: 150));
      await _obdService.sendCommand('0104\r');
      await Future.delayed(const Duration(milliseconds: 150));
      await _obdService.sendCommand('0105\r');
      await Future.delayed(const Duration(milliseconds: 150));
      await _obdService.sendCommand('010F\r');
      await Future.delayed(const Duration(milliseconds: 150));
      await _obdService.sendCommand('0111\r');
      await Future.delayed(const Duration(milliseconds: 150));
      await _obdService.sendCommand('0131\r');
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  void _checkMaintenanceStatus(int currentObdDistance) {
    if (_activeVehicle == null || _hasTriggeredMaintenanceAlert) return;
    try {
      int lastServiceKm = _activeVehicle!['last_oil_change_km'] ?? 0;
      int threshold = _activeVehicle!['oil_change_threshold_km'] ?? 5000;
      String dateString =
          _activeVehicle!['last_oil_change_date'] ??
          DateTime.now().toIso8601String();
      DateTime lastServiceDate = DateTime.parse(dateString);

      int kmsDriven = currentObdDistance - lastServiceKm;
      int monthsPassed =
          DateTime.now().difference(lastServiceDate).inDays ~/ 30;

      if (kmsDriven >= threshold || monthsPassed >= 6) {
        _hasTriggeredMaintenanceAlert = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Maintenance Alert ⚠️: Your ${_activeVehicle!['make']} is due for an oil change!",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MaintenanceScreen(
                      activeVehicle: _activeVehicle!,
                      currentOdometer: _currentDistance,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      print(e);
    }
  }

  void _handleDemoToggle(bool isEnabled) async {
    if (_activeVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a vehicle in the garage first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isDemoMode = isEnabled);

    if (isEnabled) {
      _setupRealtimeChannel();
      bool success = await _obdService.startSimulation();
      if (success) {
        setState(() => _isConnected = true);
        _startPollingData();
        _startDatabaseLogging();

        // ---> 3. ML TRIGGER FOR DEMO MODE <---
        _obdService.startMLAnalysisEngine();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demo Mode Started - AI Active'),
            backgroundColor: Colors.amber,
          ),
        );
      }
    } else {
      _isPollingData = false;
      _dbLogTimer?.cancel();
      _obdService.disconnect();
      setState(() => _isConnected = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Disconnected')));
    }
  }

  void _showConnectionManager() {
    if (_activeVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a vehicle first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ConnectionManagerSheet(
        obdService: _obdService,
        onConnected: () {
          _setupRealtimeChannel();
          setState(() {
            _isConnected = true;
            _isDemoMode = false;
          });
          _startPollingData();
          _startDatabaseLogging();

          // ---> 4. ML TRIGGER FOR HARDWARE CONNECTION <---
          _obdService.startMLAnalysisEngine();

          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hardware Connected - AI Active'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _isPollingData = false;
    _dbLogTimer?.cancel();
    _obdService.disconnect();
    _telemetryChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'DriveAI Hub',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.garage, color: Colors.cyan),
            onPressed: () async {
              final selectedCar = await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const GarageScreen()),
              );
              if (selectedCar != null && mounted) {
                setState(() {
                  _activeVehicle = selectedCar as Map<String, dynamic>;
                  _hasTriggeredMaintenanceAlert = false;
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            onPressed: () async {
              _isPollingData = false;
              _obdService.disconnect();
              await supabase.auth.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Vehicle Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "ACTIVE VEHICLE",
                      style: TextStyle(
                        color: Colors.cyan,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isConnected ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isConnected ? "CONNECTED" : "DISCONNECTED",
                          style: TextStyle(
                            color: _isConnected ? Colors.green : Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _activeVehicle != null
                      ? "${_activeVehicle!['year']} ${_activeVehicle!['make']} ${_activeVehicle!['model']}"
                      : "No Vehicle Selected",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_activeVehicle == null)
                  const Text(
                    "Tap the Garage icon in the top right to select a car.",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
              ],
            ),
          ),

          // 2. The Master Toggle
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: const Text(
                "Simulation / Demo Mode",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                "Generate fake OBD data for testing",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              activeColor: Colors.amber,
              value: _isDemoMode,
              onChanged: _handleDemoToggle,
            ),
          ),

          // 3. Navigation Grid
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildMenuCard(
                  title: "Live Telemetry",
                  icon: Icons.speed,
                  color: Colors.cyan,
                  onTap: () {
                    if (!_isConnected) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Connect to a vehicle first!'),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            LiveTelemetryScreen(obdService: _obdService),
                      ),
                    );
                  },
                ),
                _buildMenuCard(
                  title: "Trip Logger",
                  icon: Icons.map_outlined,
                  color: Colors.lightGreenAccent,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => TripScreen(
                          obdService: _obdService,
                          activeVehicle: _activeVehicle,
                        ),
                      ),
                    );
                  },
                ),
                _buildMenuCard(
                  title: "AI Mechanic",
                  icon: Icons.smart_toy,
                  color: Colors.purpleAccent,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            AiMechanicScreen(activeVehicle: _activeVehicle),
                      ),
                    );
                  },
                ),
                _buildMenuCard(
                  title: "Hardware Connect",
                  icon: Icons.bluetooth_connected,
                  color: Colors.blueAccent,
                  onTap: _showConnectionManager,
                ),
                _buildMenuCard(
                  title: "DTC Scan",
                  icon: Icons.car_crash,
                  color: Colors.orange,
                  onTap: () {
                    if (_activeVehicle == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Select a vehicle first!'),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => DtcScreen(
                          obdService: _obdService,
                          activeVehicle: _activeVehicle,
                        ),
                      ),
                    );
                  },
                ),
                _buildMenuCard(
                  title: "Maintenance",
                  icon: Icons.receipt_long,
                  color: Colors.amber,
                  onTap: () {
                    if (_activeVehicle == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Select a vehicle first!'),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MaintenanceScreen(
                          activeVehicle: _activeVehicle!,
                          currentOdometer: _currentDistance,
                        ),
                      ),
                    );
                  },
                ),
                _buildMenuCard(
                  title: "Mechanic Portal",
                  icon: Icons.engineering,
                  color: Colors.indigoAccent,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const MechanicPortalScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuCard(
                  title: "Safety Systems",
                  icon: Icons.shield,
                  color: Colors.green,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SafetyScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. LIVE TELEMETRY SCREEN (The Gauges)
// ==========================================
class LiveTelemetryScreen extends StatefulWidget {
  final OBDService obdService;
  const LiveTelemetryScreen({super.key, required this.obdService});

  @override
  State<LiveTelemetryScreen> createState() => _LiveTelemetryScreenState();
}

class _LiveTelemetryScreenState extends State<LiveTelemetryScreen> {
  int _currentRpm = 0, _currentSpeed = 0, _engineLoad = 0;
  int _coolantTemp = 0, _intakeTemp = 0, _throttlePos = 0;
  List<String> _selectedSensorIds = ['RPM', 'SPEED', 'LOAD', 'COOLANT'];

  @override
  void initState() {
    super.initState();
    // Listen to the stream purely for UI updates on this screen
    widget.obdService.obdDataStream.listen((data) {
      if (mounted) {
        setState(() {
          if (data['type'] == 'RPM') _currentRpm = data['value'];
          if (data['type'] == 'SPEED') _currentSpeed = data['value'];
          if (data['type'] == 'LOAD') _engineLoad = data['value'];
          if (data['type'] == 'COOLANT') _coolantTemp = data['value'];
          if (data['type'] == 'INTAKE') _intakeTemp = data['value'];
          if (data['type'] == 'THROTTLE') _throttlePos = data['value'];
        });
      }
    });
  }

  void _showSensorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "Customize Dashboard",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: availableSensors.map((sensor) {
                      bool isSelected = _selectedSensorIds.contains(sensor.id);
                      return CheckboxListTile(
                        title: Text(
                          sensor.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        value: isSelected,
                        activeColor: Colors.cyan,
                        onChanged: (val) {
                          setState(() {
                            if (val == true)
                              _selectedSensorIds.add(sensor.id);
                            else
                              _selectedSensorIds.remove(sensor.id);
                          });
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeConfigs = availableSensors
        .where((s) => _selectedSensorIds.contains(s.id))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'Live Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.tune, color: Colors.cyan),
            label: const Text("EDIT", style: TextStyle(color: Colors.cyan)),
            onPressed: _showSensorPicker,
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.9,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
        ),
        itemCount: activeConfigs.length,
        itemBuilder: (context, index) {
          final config = activeConfigs[index];
          double liveValue = 0.0;
          if (config.id == 'RPM') liveValue = _currentRpm.toDouble();
          if (config.id == 'SPEED') liveValue = _currentSpeed.toDouble();
          if (config.id == 'LOAD') liveValue = _engineLoad.toDouble();
          if (config.id == 'COOLANT') liveValue = _coolantTemp.toDouble();
          if (config.id == 'INTAKE') liveValue = _intakeTemp.toDouble();
          if (config.id == 'THROTTLE') liveValue = _throttlePos.toDouble();
          return _buildCustomGauge(config, liveValue);
        },
      ),
    );
  }

  Widget _buildCustomGauge(SensorConfig config, double currentValue) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: SfRadialGauge(
        title: GaugeTitle(
          text: config.name.toUpperCase(),
          textStyle: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        axes: <RadialAxis>[
          RadialAxis(
            minimum: config.min,
            maximum: config.max,
            showLabels: false,
            showTicks: false,
            axisLineStyle: const AxisLineStyle(
              thickness: 0.1,
              cornerStyle: CornerStyle.bothCurve,
              color: Color(0xFF2A2A2A),
              thicknessUnit: GaugeSizeUnit.factor,
            ),
            pointers: <GaugePointer>[
              RangePointer(
                value: currentValue,
                width: 0.1,
                sizeUnit: GaugeSizeUnit.factor,
                cornerStyle: CornerStyle.bothCurve,
                gradient: SweepGradient(
                  colors: <Color>[config.color.withOpacity(0.5), config.color],
                  stops: const <double>[0.25, 0.75],
                ),
              ),
              MarkerPointer(
                value: currentValue,
                markerType: MarkerType.circle,
                color: Colors.white,
                markerHeight: 10,
                markerWidth: 10,
              ),
            ],
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                positionFactor: 0.1,
                angle: 90,
                widget: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentValue.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      config.unit,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. CONNECTION MANAGER BOTTOM SHEET
// ==========================================
class ConnectionManagerSheet extends StatefulWidget {
  final OBDService obdService;
  final VoidCallback onConnected;
  const ConnectionManagerSheet({
    super.key,
    required this.obdService,
    required this.onConnected,
  });

  @override
  State<ConnectionManagerSheet> createState() => _ConnectionManagerSheetState();
}

class _ConnectionManagerSheetState extends State<ConnectionManagerSheet> {
  bool _showWifiConfig = false;
  bool _isScanning = false;
  List<BluetoothDevice> _devices = [];
  final _ipController = TextEditingController(text: "192.168.0.10");
  final _portController = TextEditingController(text: "35000");

  @override
  void initState() {
    super.initState();
    _getPairedDevices();
  }

  Future<void> _getPairedDevices() async {
    setState(() => _isScanning = true);
    try {
      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance
          .getBondedDevices();
      setState(() => _devices = devices);
    } catch (e) {
      print(e);
    } finally {
      setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            "CONNECT SCANNER",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showWifiConfig = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_showWifiConfig
                          ? Colors.cyan.withOpacity(0.2)
                          : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: !_showWifiConfig
                              ? Colors.cyan
                              : Colors.white24,
                          width: 2,
                        ),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        "BLUETOOTH",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showWifiConfig = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _showWifiConfig
                          ? Colors.cyan.withOpacity(0.2)
                          : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: _showWifiConfig ? Colors.cyan : Colors.white24,
                          width: 2,
                        ),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        "WI-FI",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: _showWifiConfig
                ? _buildWifiConfig()
                : _buildBluetoothScanner(),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothScanner() {
    return Column(
      children: [
        if (_isScanning)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(color: Colors.cyan),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _devices.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF2A2A2A),
                  child: Icon(Icons.bluetooth, color: Colors.cyan),
                ),
                title: Text(
                  _devices[index].name ?? "Unknown",
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  _devices[index].address,
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
                  child: const Text(
                    "Pair",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Connecting...')),
                    );
                    bool success = await widget.obdService.connectToBluetooth(
                      _devices[index],
                    );
                    if (success) {
                      widget.onConnected();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Connection failed.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWifiConfig() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _ipController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'IP Address',
                    labelStyle: const TextStyle(color: Colors.cyan),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Port',
                    labelStyle: const TextStyle(color: Colors.cyan),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () async {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Connecting...')));
              bool success = await widget.obdService.connectToWiFi(
                _ipController.text.trim(),
                int.parse(_portController.text.trim()),
              );
              if (success) {
                widget.onConnected();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Connection failed.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              "CONNECT",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
//6 AI MECHANIC SCREEN
class AiMechanicScreen extends StatefulWidget {
  final Map<String, dynamic>? activeVehicle;

  const AiMechanicScreen({super.key, this.activeVehicle});

  @override
  State<AiMechanicScreen> createState() => _AiMechanicScreenState();
}

class _AiMechanicScreenState extends State<AiMechanicScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;

  // Voice Engine Variables
  late stt.SpeechToText _speech;
  bool _isListening = false;
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initializeVoiceEngines();

    String carName = widget.activeVehicle != null
        ? "${widget.activeVehicle!['year']} ${widget.activeVehicle!['make']}"
        : "your vehicle";

    _addMessage(
      'ai',
      "Hello! I am your AI Mechanic. How can I help you with $carName today?\n\n(میں آپ کا اے آئی مکینک ہوں۔ میں آج آپ کی گاڑی کے ساتھ کیا مدد کر سکتا ہوں؟)",
    );
  }

  // --- 1. VOICE ENGINE SETUP ---
  void _initializeVoiceEngines() async {
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();

    // Configure the TTS Voice
    await _flutterTts.setLanguage("ur-PK");
    await _flutterTts.setSpeechRate(
      0.5,
    ); // Slightly slower, clear mechanic voice
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() => setState(() => _isSpeaking = true));
    _flutterTts.setCompletionHandler(() => setState(() => _isSpeaking = false));
    _flutterTts.setErrorHandler((msg) => setState(() => _isSpeaking = false));
  }

  // --- 2. SPEECH TO TEXT LOGIC ---
  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        // Stop any current AI speech so it can hear you
        if (_isSpeaking) _flutterTts.stop();

        _speech.listen(
          onResult: (val) => setState(() {
            _chatController.text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      // Automatically send the message when you stop talking
      if (_chatController.text.isNotEmpty) {
        _sendMessage(_chatController.text);
      }
    }
  }

  // Helper to add messages and read AI responses aloud
  void _addMessage(String role, String text) {
    setState(() {
      _messages.add({'role': role, 'text': text});
    });
    _scrollToBottom();

    // If the AI is responding, read it out loud!
    if (role == 'ai') {
      _flutterTts.speak(text);
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Stop speaking if user interrupts
    if (_isSpeaking) await _flutterTts.stop();

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isTyping = true;
    });

    _chatController.clear();
    _scrollToBottom();

    String carContext = widget.activeVehicle != null
        ? "Vehicle: ${widget.activeVehicle!['year']} ${widget.activeVehicle!['make']} ${widget.activeVehicle!['model']}."
        : "No specific vehicle selected.";

    try {
      // final url = Uri.parse('http://192.168.100.23:8000/chat');  home network
      // final url = Uri.parse('http://192.168.120.166/chat'); // Updated IP from your earlier message (mobile hotspot)
      final url = Uri.parse('https://ai-mechanic-backend.onrender.com/chat');


      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'prompt': text, 'context': carContext}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() => _isTyping = false);
        _addMessage(
          'ai',
          responseData['response'] ??
              "I received a response, but couldn't read the text.",
        );
      } else {
        setState(() => _isTyping = false);
        _addMessage('ai', "Server Error: ${response.statusCode}.");
      }
    } catch (e) {
      setState(() => _isTyping = false);
      _addMessage('ai', "Network Error: Could not connect to the backend.");
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _flutterTts.stop(); // Stop audio when leaving screen
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.smart_toy, color: Colors.purpleAccent),
            const SizedBox(width: 10),
            const Text(
              'AI Mechanic',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            // Stop Audio Button
            if (_isSpeaking)
              IconButton(
                icon: const Icon(Icons.volume_off, color: Colors.redAccent),
                onPressed: () => _flutterTts.stop(),
                tooltip: "Stop Speaking",
              ),
          ],
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return _buildChatBubble(msg['text']!, isUser);
              },
            ),
          ),

          if (_isTyping)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "AI is thinking...",
                  style: TextStyle(
                    color: Colors.purpleAccent,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildQuickActionChip("اس کے اسباب کیا ہیں؟ (Causes)"),
                _buildQuickActionChip("اسے کیسے ٹھیک کریں؟ (How to fix)"),
                _buildQuickActionChip("کیا یہ محفوظ ہے؟ (Is it safe?)"),
                _buildQuickActionChip("Estimated Repair Cost"),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (val) =>
                        setState(() {}), // Update UI to switch mic/send icon
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? "Listening..."
                          : "Ask about a noise, code...",
                      hintStyle: TextStyle(
                        color: _isListening
                            ? Colors.purpleAccent
                            : Colors.white54,
                      ),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),

                // Dynamic Send / Mic Button
                GestureDetector(
                  onTap: () {
                    if (_chatController.text.isNotEmpty) {
                      _sendMessage(_chatController.text);
                    } else {
                      _listen();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isListening
                          ? Colors.redAccent
                          : Colors.purpleAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _chatController.text.isNotEmpty
                          ? Icons.send
                          : (_isListening ? Icons.mic : Icons.mic_none),
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Colors.cyan.withOpacity(0.2)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
          border: Border.all(
            color: isUser ? Colors.cyan.withOpacity(0.5) : Colors.white12,
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildQuickActionChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        backgroundColor: const Color(0xFF2A2A2A),
        side: const BorderSide(color: Colors.purpleAccent),
        label: Text(label, style: const TextStyle(color: Colors.white)),
        onPressed: () => _sendMessage(label),
      ),
    );
  }
}
