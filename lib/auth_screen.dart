import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

// Your custom file imports
import 'main.dart'; 
import 'obd_service.dart'; 
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message), backgroundColor: Colors.red));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('An unexpected error occurred'), backgroundColor: Colors.red));
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
                  Text(_isLogin ? 'LOGIN' : 'REGISTER', textAlign: TextAlign.center, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                  const SizedBox(height: 40),
                  
                  if (!_isLogin) ...[
                    const Text('USERNAME', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _usernameController, style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(hintText: 'Enter username', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      validator: (value) => value!.isEmpty ? 'Please enter a username' : null,
                    ),
                    const SizedBox(height: 20),
                  ],

                  const Text('EMAIL', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(hintText: 'Enter email', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    validator: (value) => value!.isEmpty || !value.contains('@') ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 20),

                  const Text('PASSWORD', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController, obscureText: true, style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(hintText: 'Enter password', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    validator: (value) => value!.length < 6 ? 'Password must be 6+ chars' : null,
                  ),
                  const SizedBox(height: 30),

                  _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          onPressed: _submitForm,
                          child: Text(_isLogin ? 'LOGIN' : 'REGISTER', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: () => setState(() { _isLogin = !_isLogin; _formKey.currentState?.reset(); }),
                    child: RichText(text: TextSpan(text: _isLogin ? "Don't have an account? " : "Already have an account? ", style: const TextStyle(color: Colors.white), children: [TextSpan(text: _isLogin ? 'Signup' : 'Login', style: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))])),
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

  RealtimeChannel? _telemetryChannel;

  // Connection UI State
  bool _showWifiConfig = false; 
  final _ipController = TextEditingController(text: "192.168.0.10"); 
  final _portController = TextEditingController(text: "35000"); 

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

        // Push data to the Supabase Cloud
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

  void _setupRealtimeChannel() {
    if (_activeVehicle == null) return;
    final channelName = 'telemetry_${_activeVehicle!['id']}';
    _telemetryChannel = supabase.channel(channelName);
    
    _telemetryChannel!.subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        print('Successfully connected to Supabase Realtime Channel: $channelName');
      }
    });
  }

  Future<void> _requestPermissions() async {
    await [Permission.bluetoothConnect, Permission.bluetoothScan, Permission.location].request();
    _getPairedDevices();
  }

  Future<void> _getPairedDevices() async {
    setState(() => _isScanning = true);
    try {
      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() => _devices = devices);
    } catch (e) { print("Error getting devices: $e"); } 
    finally { setState(() => _isScanning = false); }
  }

  void _startPollingData() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_obdService.isConnected) { timer.cancel(); return; }
      await _obdService.sendCommand('010C\r'); // Ask for RPM
      await Future.delayed(const Duration(milliseconds: 300)); 
      await _obdService.sendCommand('010D\r'); // Ask for Speed
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _obdService.disconnect();
    _telemetryChannel?.unsubscribe(); 
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(_isConnectedToCar ? 'Telemetry Active' : 'Live Diagnostic', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.garage),
            onPressed: () async {
              final selectedCar = await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const GarageScreen()));
              if (selectedCar != null && mounted) {
                setState(() => _activeVehicle = selectedCar as Map<String, dynamic>);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Active Vehicle set to: ${_activeVehicle!['make']} ${_activeVehicle!['model']}')));
              }
            },
          ),
          if (!_isConnectedToCar && !_showWifiConfig) IconButton(icon: const Icon(Icons.refresh), onPressed: _getPairedDevices),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              _pollingTimer?.cancel();
              _telemetryChannel?.unsubscribe();
              _obdService.disconnect();
              await supabase.auth.signOut();
              if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const AuthScreen()));
            },
          )
        ],
      ),
      body: _isConnectedToCar ? _buildLiveDashboard() : _buildDeviceScanner(),
    );
  }

  Widget _buildDeviceScanner() {
    return Column(
      children: [
        // --- ACTIVE VEHICLE CARD ---
        Container(
          width: double.infinity, padding: const EdgeInsets.all(16), color: const Color(0xFF1E1E1E),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("ACTIVE VEHICLE", style: TextStyle(color: Colors.cyan, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Text(_activeVehicle != null ? "${_activeVehicle!['year']} ${_activeVehicle!['make']} ${_activeVehicle!['model']}" : "No vehicle selected", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              if (_activeVehicle == null) const Text("Tap the Garage icon in the top right to select a car.", style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),

        // --- THE CONNECTION TOGGLE ---
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showWifiConfig = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_showWifiConfig ? Colors.cyan.withOpacity(0.2) : Colors.transparent,
                      border: Border(bottom: BorderSide(color: !_showWifiConfig ? Colors.cyan : Colors.white24, width: 2)),
                    ),
                    child: const Center(child: Text("BLUETOOTH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showWifiConfig = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _showWifiConfig ? Colors.cyan.withOpacity(0.2) : Colors.transparent,
                      border: Border(bottom: BorderSide(color: _showWifiConfig ? Colors.cyan : Colors.white24, width: 2)),
                    ),
                    child: const Center(child: Text("WI-FI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ),
                ),
              ),
            ],
          ),
        ),

        // --- DYNAMIC CONTENT AREA ---
        Expanded(
          child: _showWifiConfig ? _buildWifiConfig() : _buildBluetoothScanner(),
        ),

        // --- SIMULATION BUTTON ---
        Container(
          margin: const EdgeInsets.all(16.0), width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700], padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            icon: const Icon(Icons.developer_mode, color: Colors.black),
            label: const Text("START SIMULATION MODE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            onPressed: () async {
              if (_activeVehicle == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a vehicle first.'), backgroundColor: Colors.red));
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Starting Simulator...'), duration: Duration(seconds: 1)));
              
              _setupRealtimeChannel(); 
              bool success = await _obdService.startSimulation(); 
              if (mounted && success) setState(() => _isConnectedToCar = true);
            },
          ),
        ),
      ],
    );
  }

  // --- SUB-WIDGET: BLUETOOTH LIST ---
  Widget _buildBluetoothScanner() {
    return Column(
      children: [
        if (_isScanning) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Colors.cyan)),
        Expanded(
          child: ListView.builder(
            itemCount: _devices.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFF1E1E1E), child: Icon(Icons.bluetooth, color: Colors.cyan)),
                title: Text(_devices[index].name ?? "Unknown Device", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(_devices[index].address, style: const TextStyle(color: Colors.white54)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: const Text("Connect", style: TextStyle(color: Colors.white)),
                  onPressed: () async {
                    if (_activeVehicle == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a vehicle first.'), backgroundColor: Colors.red));
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connecting to Bluetooth...')));
                    
                    _setupRealtimeChannel(); 
                    bool success = await _obdService.connectToBluetooth(_devices[index]); 
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      if (success) {
                        setState(() => _isConnectedToCar = true);
                        _startPollingData(); 
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection failed.'), backgroundColor: Colors.red));
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

  // --- SUB-WIDGET: WI-FI FORM ---
  Widget _buildWifiConfig() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.wifi_tethering, size: 60, color: Colors.cyan),
          const SizedBox(height: 20),
          const Text("Ensure your phone is connected to the OBD-II adapter's Wi-Fi network before connecting.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _ipController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(labelText: 'IP Address', labelStyle: const TextStyle(color: Colors.cyan), filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(labelText: 'Port', labelStyle: const TextStyle(color: Colors.cyan), filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              if (_activeVehicle == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a vehicle first.'), backgroundColor: Colors.red));
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Establishing TCP Socket Connection...')));
              
              _setupRealtimeChannel(); 
              bool success = await _obdService.connectToWiFi(_ipController.text.trim(), int.parse(_portController.text.trim()));
              
              if (mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                if (success) {
                  setState(() => _isConnectedToCar = true);
                  _startPollingData(); 
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('TCP Connection failed. Check Wi-Fi settings.'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text("CONNECT VIA WI-FI", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- SUB-WIDGET: LIVE DASHBOARD ---
  Widget _buildLiveDashboard() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_upload, color: Colors.green, size: 40), 
          const Text("BROADCASTING LIVE", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 30),
          const Icon(Icons.speed, size: 80, color: Colors.cyan),
          const SizedBox(height: 20),
          Text("$_currentRpm", style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.white)),
          const Text("RPM", style: TextStyle(fontSize: 20, color: Colors.white54, letterSpacing: 2)),
          const SizedBox(height: 40),
          Text("$_currentSpeed", style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.white)),
          const Text("KM/H", style: TextStyle(fontSize: 20, color: Colors.white54, letterSpacing: 2)),
          const SizedBox(height: 60),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
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
            child: const Text("Disconnect", style: TextStyle(color: Colors.white, fontSize: 18)),
          )
        ],
      ),
    );
  }
}