import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'obd_service.dart'; // Ensure this points to your OBD file
import 'main.dart'; // For your global supabase variable

class TripScreen extends StatefulWidget {
  final OBDService obdService;
  final Map<String, dynamic>? activeVehicle;

  const TripScreen({super.key, required this.obdService, this.activeVehicle});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  final MapController _mapController = MapController();

  bool _isTracking = false;
  List<LatLng> _routePoints = [];

  // Stream Subscriptions
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<dynamic>? _obdStream;

  // Live Stats
  double _currentSpeed = 0;
  double _currentRpm = 0;
  double _totalDistanceKm = 0.0;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndGetLocation();
  }

  Future<void> _checkPermissionsAndGetLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // Get initial location to center the map
    Position initialPos = await Geolocator.getCurrentPosition();
    setState(() {
      _routePoints.add(LatLng(initialPos.latitude, initialPos.longitude));
    });
    _mapController.move(
      LatLng(initialPos.latitude, initialPos.longitude),
      16.0,
    );
  }

  void _toggleTracking() {
    if (_isTracking) {
      _endTrip();
    } else {
      _startTrip();
    }
  }

  void _startTrip() {
    if (widget.activeVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a vehicle in the garage first!"),
        ),
      );
      return;
    }

    setState(() {
      _isTracking = true;
      _routePoints.clear();
      _totalDistanceKm = 0.0;
      _startTime = DateTime.now();
    });

    // 1. Start GPS Tracking
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((Position position) {
          if (mounted) {
            setState(() {
              LatLng newPoint = LatLng(position.latitude, position.longitude);
              if (_routePoints.isNotEmpty) {
                // Calculate distance added
                _totalDistanceKm +=
                    Geolocator.distanceBetween(
                      _routePoints.last.latitude,
                      _routePoints.last.longitude,
                      newPoint.latitude,
                      newPoint.longitude,
                    ) /
                    1000; // Convert meters to km
              }
              _routePoints.add(newPoint);
              _mapController.move(newPoint, 17.0); // Keep map centered on user
            });
          }
        });

    // 2. Start OBD Tracking
    _obdStream = widget.obdService.obdDataStream.listen((data) {
      if (mounted) {
        setState(() {
          if (data['type'] == 'SPEED') _currentSpeed = data['value'].toDouble();
          if (data['type'] == 'RPM') _currentRpm = data['value'].toDouble();
        });
      }
    });
  }

  Future<void> _endTrip() async {
    setState(() => _isTracking = false);
    _positionStream?.cancel();
    _obdStream?.cancel();

    if (_routePoints.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Trip too short to save.")));
      return;
    }

    final duration = DateTime.now().difference(_startTime!);

    // Show Saving Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.cyan)),
    );

    // Save to Supabase (Ensure you create a 'trips' table in your Supabase dashboard!)
    try {
      await supabase.from('trips').insert({
        'vehicle_id': widget.activeVehicle!['id'],
        'distance_km': _totalDistanceKm,
        'duration_minutes': duration.inMinutes,
        'start_time': _startTime!.toIso8601String(),
        'end_time': DateTime.now().toIso8601String(),
        // You can even save the raw GPS coordinates as JSON if you want to redraw the map later!
      });

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Trip Saved Successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving trip: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _obdStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'Live Trip Tracker',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // 1. The Map Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _routePoints.isNotEmpty
                  ? _routePoints.last
                  : const LatLng(33.6844, 73.0479), // Default Islamabad/Pindi
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.driveai.app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 5.0,
                    color: Colors.cyanAccent, // Your custom route color
                  ),
                ],
              ),
              // Show a marker for the current car location
              if (_routePoints.isNotEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _routePoints.last,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.navigation,
                        color: Colors.cyan,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 2. The OBD Stats Overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyan.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatTile(
                    "SPEED",
                    "${_currentSpeed.toInt()}",
                    "km/h",
                    Colors.greenAccent,
                  ),
                  _buildStatTile(
                    "RPM",
                    "${_currentRpm.toInt()}",
                    "rpm",
                    Colors.orangeAccent,
                  ),
                  _buildStatTile(
                    "DIST",
                    _totalDistanceKm.toStringAsFixed(2),
                    "km",
                    Colors.cyan,
                  ),
                ],
              ),
            ),
          ),

          // 3. Start/Stop Button
          Positioned(
            bottom: 30,
            left: 30,
            right: 30,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTracking ? Colors.redAccent : Colors.cyan,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 10,
              ),
              onPressed: _toggleTracking,
              child: Text(
                _isTracking ? "END TRIP & SAVE" : "START TRIP",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, String unit, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(unit, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}
