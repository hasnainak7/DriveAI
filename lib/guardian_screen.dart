import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

class GuardianScreen extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  
  const GuardianScreen({super.key, required this.vehicle});

  @override
  State<GuardianScreen> createState() => _GuardianScreenState();
}

class _GuardianScreenState extends State<GuardianScreen> {
  RealtimeChannel? _listenChannel;
  
  int _remoteRpm = 0;
  int _remoteSpeed = 0;
  String _lastUpdateTime = "Waiting for signal...";
  bool _isReceiving = false;

  @override
  void initState() {
    super.initState();
    _setupRemoteListener();
  }

  void _setupRemoteListener() {
    final channelName = 'telemetry_${widget.vehicle['id']}';
    
    // 1. Initialize the channel
    _listenChannel = supabase.channel(channelName);
    
    // 2. Set up the listener for our 'live_data' broadcasts
    _listenChannel!.onBroadcast(
      event: 'live_data', 
      callback: (payload) {
        if (mounted) {
          setState(() {
            _remoteRpm = payload['rpm'];
            _remoteSpeed = payload['speed'];
            _isReceiving = true;
            
            // Format the timestamp nicely
            final time = DateTime.parse(payload['timestamp']).toLocal();
            _lastUpdateTime = "${time.hour}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}";
          });
        }
      }
    ).subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        print('Guardian Portal connected to $channelName');
      }
    });
  }

  @override
  void dispose() {
    _listenChannel?.unsubscribe(); // Always clean up WebSockets!
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // A distinct dark blue background for the Mechanic/Guardian view
      backgroundColor: const Color(0xFF0A1128), 
      appBar: AppBar(
        title: const Text('Remote Guardian Portal', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF001F54),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${widget.vehicle['year']} ${widget.vehicle['make']} ${widget.vehicle['model']}",
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              "VIN: ${widget.vehicle['vin_number'] ?? 'N/A'}",
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 40),
            
            // Connection Status Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isReceiving ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _isReceiving ? Colors.green : Colors.orange),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isReceiving ? Icons.wifi_tethering : Icons.portable_wifi_off, 
                    color: _isReceiving ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isReceiving ? "LIVE CONNECTION" : "AWAITING TELEMETRY",
                    style: TextStyle(color: _isReceiving ? Colors.green : Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 50),
            
            // Remote RPM Gauge
            Text(
              "$_remoteRpm", 
              style: const TextStyle(fontSize: 70, fontWeight: FontWeight.bold, color: Colors.blueAccent)
            ),
            const Text("REMOTE RPM", style: TextStyle(fontSize: 18, color: Colors.white54, letterSpacing: 2)),
            
            const SizedBox(height: 40),
            
            // Remote Speed Gauge
            Text(
              "$_remoteSpeed", 
              style: const TextStyle(fontSize: 70, fontWeight: FontWeight.bold, color: Colors.blueAccent)
            ),
            const Text("REMOTE KM/H", style: TextStyle(fontSize: 18, color: Colors.white54, letterSpacing: 2)),
            
            const SizedBox(height: 60),
            Text("Last Update: $_lastUpdateTime", style: const TextStyle(color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}