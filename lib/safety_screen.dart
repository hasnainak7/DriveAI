import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  
  double _x = 0.0;
  double _y = 0.0;
  double _z = 0.0;
  double _totalGForce = 0.0;
  double _maxGForce = 0.0;

  // The threshold for a severe event (approx 3.0 Gs = ~29 m/s^2)
  // Standard braking is ~0.5G to 1.0G. A crash is typically 3.0G+
  final double _crashThreshold = 29.0; 
  
  bool _isCrashDetected = false;
  int _sosCountdown = 10;
  Timer? _sosTimer;

  @override
  void initState() {
    super.initState();
    _startSafetyMonitor();
  }

  void _startSafetyMonitor() {
    _accelSubscription = userAccelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((event) {
      if (!mounted || _isCrashDetected) return;

      setState(() {
        _x = event.x;
        _y = event.y;
        _z = event.z;

        // Calculate the magnitude vector (Total Force)
        _totalGForce = sqrt((_x * _x) + (_y * _y) + (_z * _z));

        // Track the highest force seen this session
        if (_totalGForce > _maxGForce) _maxGForce = _totalGForce;

        // Trigger the Edge AI Rules Engine
        if (_totalGForce >= _crashThreshold) {
          _triggerSosProtocol();
        }
      });
    });
  }

  void _triggerSosProtocol() {
    setState(() => _isCrashDetected = true);
    
    // Start a 10-second countdown to allow the user to cancel a false alarm
    _sosTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_sosCountdown > 0) {
          _sosCountdown--;
        } else {
          timer.cancel();
          // TODO: Integrate with Twilio/SMS API to text emergency contacts
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SOS DISPATCHED TO EMERGENCY CONTACTS!'), backgroundColor: Colors.red, duration: Duration(seconds: 5)),
          );
        }
      });
    });
  }

  void _cancelSos() {
    _sosTimer?.cancel();
    setState(() {
      _isCrashDetected = false;
      _sosCountdown = 10;
      _maxGForce = 0.0; // Reset max after an event
    });
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    _sosTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If a crash is detected, hijack the whole screen with a red overlay
    if (_isCrashDetected) {
      return Scaffold(
        backgroundColor: Colors.red[900],
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 100),
                const SizedBox(height: 20),
                const Text("CRASH DETECTED", style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 10),
                const Text("Dispatching Emergency Services in:", style: TextStyle(color: Colors.white70, fontSize: 18)),
                const SizedBox(height: 40),
                Text("$_sosCountdown", style: const TextStyle(color: Colors.white, fontSize: 120, fontWeight: FontWeight.bold)),
                const SizedBox(height: 60),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red[900],
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: _cancelSos,
                  child: const Text("I AM OKAY - CANCEL SOS", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        ),
      );
    }

    // Standard Monitoring UI
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Edge AI Safety Module', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.shield, color: Colors.green, size: 60),
            const SizedBox(height: 16),
            const Text("ACTIVE MONITORING", textAlign: TextAlign.center, style: TextStyle(color: Colors.green, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const Text("Crash detection is running locally via phone sensors.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14)),
            
            const SizedBox(height: 60),
            
            // Live G-Force Meter
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.cyan, width: 4),
                color: const Color(0xFF1E1E1E),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    (_totalGForce / 9.81).toStringAsFixed(2), // Convert raw m/s^2 to standard 'G' force
                    style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Text("G-FORCE", style: TextStyle(color: Colors.cyan, letterSpacing: 2)),
                ],
              ),
            ),
            
            const SizedBox(height: 60),
            
            // Raw Telemetry Stats
            _buildStatRow("Max Force Logged", "${(_maxGForce / 9.81).toStringAsFixed(2)} G"),
            _buildStatRow("X-Axis (Sway)", "${_x.toStringAsFixed(1)} m/s²"),
            _buildStatRow("Y-Axis (Braking)", "${_y.toStringAsFixed(1)} m/s²"),
            _buildStatRow("Z-Axis (Vertical)", "${_z.toStringAsFixed(1)} m/s²"),
            
            const Spacer(),
            
            // Developer Testing Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800], padding: const EdgeInsets.symmetric(vertical: 16)),
              icon: const Icon(Icons.bug_report, color: Colors.black),
              label: const Text("SIMULATE CRASH", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              onPressed: () {
                setState(() => _totalGForce = 35.0); // Artificially inject a 3.5G spike
                _triggerSosProtocol();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}