import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

import 'main.dart';
import 'obd_service.dart';
import 'add_vehicle_screen.dart';
import 'garage_screen.dart';

// ==========================================
// 1. THE AUTHENTICATION SCREEN
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
        await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {'full_name': _usernameController.text.trim()},
        );
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } on AuthException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred'),
            backgroundColor: Colors.red,
          ),
        );
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
                    validator: (value) => value!.isEmpty || !value.contains('@')
                        ? 'Enter a valid email'
                        : null,
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
                              color: Colors.white,
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
// 2. THE HARDWARE DASHBOARD SCREEN
// ==========================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final OBDService _obdService = OBDService();
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  bool _isConnectedToCar = false;

  int _currentRpm = 0;
  int _currentSpeed = 0;
  Timer? _pollingTimer;
  Map<String, dynamic>? _activeVehicle;

  // ---> SPRINT 7: THE REALTIME CHANNEL <---
  RealtimeChannel? _telemetryChannel;

  @override
  void initState() {
    super.initState();
    _requestPermissions();

    // Listen to the data coming from our OBD parser (or simulator)
    _obdService.obdDataStream.listen((data) {
      if (mounted) {
        setState(() {
          if (data['type'] == 'RPM') _currentRpm = data['value'];
          if (data['type'] == 'SPEED') _currentSpeed = data['value'];
        });

        // ---> SPRINT 7: PUSH DATA TO THE CLOUD <---
        if (_isConnectedToCar && _telemetryChannel != null) {
          _telemetryChannel!.sendBroadcastMessage(
            event: 'live_data',
            payload: {
              'vehicle_id': _activeVehicle!['id'],
              'rpm': _currentRpm,
              'speed': _currentSpeed,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
      }
    });
  }

  // ---> SPRINT 7: SETUP WEBSOCKET CONNECTION <---
  void _setupRealtimeChannel() {
    if (_activeVehicle == null) return;

    // Create a unique room for this specific car
    final channelName = 'telemetry_${_activeVehicle!['id']}';
    _telemetryChannel = supabase.channel(channelName);

    _telemetryChannel!.subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        print(
          'Successfully connected to Supabase Realtime Channel: $channelName',
        );
      }
    });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
    _getPairedDevices();
  }

  Future<void> _getPairedDevices() async {
    setState(() => _isScanning = true);
    try {
      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance
          .getBondedDevices();
      setState(() => _devices = devices);
    } catch (e) {
      print("Error getting devices: $e");
    } finally {
      setState(() => _isScanning = false);
    }
  }

  void _startPollingData() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_obdService.isConnected) {
        timer.cancel();
        return;
      }
      await _obdService.sendCommand('010C\r'); // Ask for RPM
      await Future.delayed(const Duration(milliseconds: 300));
      await _obdService.sendCommand('010D\r'); // Ask for Speed
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _obdService.disconnect();
    _telemetryChannel?.unsubscribe(); // Clean up WebSocket
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          _isConnectedToCar ? 'Telemetry Active' : 'Live Diagnostic',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.garage),
            onPressed: () async {
              final selectedCar = await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const GarageScreen()),
              );
              if (selectedCar != null && mounted) {
                setState(
                  () => _activeVehicle = selectedCar as Map<String, dynamic>,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Active Vehicle set to: ${_activeVehicle!['make']} ${_activeVehicle!['model']}',
                    ),
                  ),
                );
              }
            },
          ),
          if (!_isConnectedToCar)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _getPairedDevices,
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              _pollingTimer?.cancel();
              _telemetryChannel?.unsubscribe();
              _obdService.disconnect();
              await supabase.auth.signOut();
              if (mounted)
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                );
            },
          ),
        ],
      ),
      body: _isConnectedToCar ? _buildLiveDashboard() : _buildDeviceScanner(),
    );
  }

  Widget _buildDeviceScanner() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF1E1E1E),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 4),
              Text(
                _activeVehicle != null
                    ? "${_activeVehicle!['year']} ${_activeVehicle!['make']} ${_activeVehicle!['model']}"
                    : "No vehicle selected",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
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

        Container(
          margin: const EdgeInsets.all(16.0),
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.developer_mode, color: Colors.black),
            label: const Text(
              "START SIMULATION MODE",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            onPressed: () async {
              if (_activeVehicle == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please select a vehicle from the Garage first.',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Starting Simulator...'),
                  duration: Duration(seconds: 1),
                ),
              );

              _setupRealtimeChannel(); // <-- Initialize WebSocket
              bool success = await _obdService.startSimulation();

              if (mounted && success) setState(() => _isConnectedToCar = true);
            },
          ),
        ),
        const Divider(color: Colors.white24, thickness: 2),

        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "Or Select a Real ELM327 Adapter",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
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
                leading: const Icon(Icons.bluetooth, color: Colors.cyan),
                title: Text(
                  _devices[index].name ?? "Unknown Device",
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  _devices[index].address,
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
                  child: const Text(
                    "Connect",
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () async {
                    if (_activeVehicle == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please select a vehicle from the Garage first.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Attempting connection...')),
                    );

                    _setupRealtimeChannel(); // <-- Initialize WebSocket
                    bool success = await _obdService.connectToDevice(
                      _devices[index],
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      if (success) {
                        setState(() => _isConnectedToCar = true);
                        _startPollingData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Connected to OBD-II!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Connection failed. Is the car on?'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
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

  Widget _buildLiveDashboard() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_upload,
            color: Colors.green,
            size: 40,
          ), // Indicator that we are pushing to cloud
          const Text(
            "BROADCASTING LIVE",
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 30),
          const Icon(Icons.speed, size: 80, color: Colors.cyan),
          const SizedBox(height: 20),
          Text(
            "$_currentRpm",
            style: const TextStyle(
              fontSize: 60,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            "RPM",
            style: TextStyle(
              fontSize: 20,
              color: Colors.white54,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            "$_currentSpeed",
            style: const TextStyle(
              fontSize: 60,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            "KM/H",
            style: TextStyle(
              fontSize: 20,
              color: Colors.white54,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 60),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
            onPressed: () {
              _pollingTimer?.cancel();
              _telemetryChannel?.unsubscribe();
              _obdService.disconnect();
              setState(() {
                _isConnectedToCar = false;
                _currentRpm = 0;
                _currentSpeed = 0;
              });
            },
            child: const Text(
              "Disconnect",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}
