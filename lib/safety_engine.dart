import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

// Use an explicit alias to ensure the engine always knows where navigatorKey is
import 'main.dart' as app_main;

class SafetyEngine {
  // --- Singleton Setup ---
  // This ensures only ONE instance of the engine ever exists in the app.
  static final SafetyEngine _instance = SafetyEngine._internal();
  factory SafetyEngine() => _instance;
  SafetyEngine._internal();

  bool _isMonitoring = false;
  StreamSubscription<UserAccelerometerEvent>? _sensorSubscription;

  // 1. Initialize Engine
  Future<void> initializeEngine() async {
    print("Safety Engine Initializing...");
  }

  // 2. Start the Global Sensor Loop
  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    print("Safety Engine: Armed & Monitoring.");

    // We use a debounce timer so it doesn't trigger 50 times in one second
    DateTime? lastAlertTime;

    _sensorSubscription = userAccelerometerEventStream().listen((event) {
      // Calculate absolute acceleration (Vector Magnitude)
      double acceleration = sqrt(
        pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2),
      );

      // Convert to G-Force (1 G = 9.81 m/s^2)
      double gForce = acceleration / 9.81;

      // The Crash Threshold
      // Set to 4.0 for testing so you can trigger it by shaking the phone!
      bool isCrashDetected = gForce > 4.0;

      if (isCrashDetected) {
        // Prevent multiple triggers within 15 seconds
        if (lastAlertTime == null ||
            DateTime.now().difference(lastAlertTime!).inSeconds > 15) {
          lastAlertTime = DateTime.now();
          print("⚠️ IMPACT DETECTED! G-Force: ${gForce.toStringAsFixed(2)}G");
          _triggerGlobalSOSProtocol();
        }
      }
    });
  }

  // 3. Stop Monitoring
  void stopMonitoring() {
    _sensorSubscription?.cancel();
    _isMonitoring = false;
    print("Safety Engine: Disarmed.");
  }

  // 4. The Global Alert with Live Timer & Auto-Dial
  void _triggerGlobalSOSProtocol() {
    // Stop listening temporarily so we don't spam popups during a crash
    stopMonitoring();

    // Grab the global context from main.dart using the alias
    final context = app_main.navigatorKey.currentContext;

    if (context == null) {
      print(
        "Safety Engine Error: Could not find global context for SOS popup.",
      );
      return;
    }

    int countdown = 10;
    Timer? sosTimer;

    // Show the SOS dialog over WHATEVER screen the user is currently on!
    showDialog(
      context: context,
      barrierDismissible: false, // Force them to interact with it
      builder: (context) {
        // StatefulBuilder allows us to update the UI INSIDE the dialog live!
        return StatefulBuilder(
          builder: (context, setState) {
            // Initialize the timer only once when the dialog first builds
            sosTimer ??= Timer.periodic(const Duration(seconds: 1), (
              timer,
            ) async {
              if (countdown > 1) {
                // Update the UI to show the new number
                setState(() => countdown--);
              } else {
                // TIMER HIT ZERO!
                timer.cancel();
                Navigator.pop(context); // Close the dialog automatically
                startMonitoring(); // Re-arm the system in the background

                // ---> TRIGGER DIRECT PHONE CALL <---
                // CHANGE THIS NUMBER TO A FRIEND'S NUMBER FOR TESTING!
                const String emergencyNumber = '03099619155';

                print("Initiating direct call to $emergencyNumber...");
                bool? res = await FlutterPhoneDirectCaller.callNumber(
                  emergencyNumber,
                );
                if (res == false) {
                  print(
                    "Error: Could not place direct call. Check Android permissions.",
                  );
                }
              }
            });

            return AlertDialog(
              backgroundColor: Colors.red[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'CRASH DETECTED',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Severe impact detected. Initiating emergency protocols...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // LIVE COUNTDOWN TEXT
                  Text(
                    '$countdown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'Calling emergency services automatically...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              actions: [
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      // USER IS OKAY - CANCEL EVERYTHING
                      sosTimer?.cancel();
                      Navigator.pop(context);
                      startMonitoring();
                    },
                    child: Text(
                      "I'M OKAY - CANCEL",
                      style: TextStyle(
                        color: Colors.red[900],
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Failsafe: If the dialog is closed by a back swipe, kill the timer.
      sosTimer?.cancel();
    });
  }
}
