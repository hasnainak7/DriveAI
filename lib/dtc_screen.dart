import 'dart:async';
import 'package:flutter/material.dart';
import 'obd_service.dart';

class DtcScreen extends StatefulWidget {
  final OBDService obdService;
  
  const DtcScreen({super.key, required this.obdService});

  @override
  State<DtcScreen> createState() => _DtcScreenState();
}

class _DtcScreenState extends State<DtcScreen> {
  List<String> _troubleCodes = [];
  bool _isScanning = false;
  bool _hasScanned = false;
  StreamSubscription? _obdSubscription;

  // A basic dictionary to tell the user what the code actually means
  final Map<String, String> _dtcDictionary = {
    'P0301': 'Cylinder 1 Misfire Detected',
    'P0420': 'Catalyst System Efficiency Below Threshold (Bank 1)',
    'P0100': 'Mass or Volume Air Flow Circuit Malfunction',
    'P0171': 'System Too Lean (Bank 1)',
  };

  @override
  void initState() {
    super.initState();
    // Listen to the hardware for DTC replies
    _obdSubscription = widget.obdService.obdDataStream.listen((data) {
      if (mounted) {
        if (data['type'] == 'DTC') {
          setState(() {
            _troubleCodes = List<String>.from(data['codes']);
            _isScanning = false;
            _hasScanned = true;
          });
        }
        if (data['type'] == 'DTC_CLEARED') {
          setState(() {
            _troubleCodes.clear();
            _isScanning = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Codes Cleared Successfully!'), backgroundColor: Colors.green),
          );
        }
      }
    });
  }

  void _scanForCodes() async {
    setState(() {
      _isScanning = true;
      _hasScanned = false;
    });
    // Send the Mode 03 command to the ECU
    await widget.obdService.requestDTCs();
  }

  void _clearCodes() async {
    // Standard safety warning before clearing codes
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Clear Check Engine Light?', style: TextStyle(color: Colors.white)),
        content: const Text('This will erase all emissions-related diagnostic information from the ECU. Are you sure?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(child: const Text('Cancel', style: TextStyle(color: Colors.white54)), onPressed: () => Navigator.pop(context, false)),
          TextButton(child: const Text('Clear Codes', style: TextStyle(color: Colors.redAccent)), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    ) ?? false;

    if (confirm) {
      setState(() => _isScanning = true);
      // Send the Mode 04 command to the ECU
      await widget.obdService.clearDTCs();
    }
  }

  @override
  void dispose() {
    _obdSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Diagnostic Codes', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Control Panel
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF1E1E1E),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  icon: _isScanning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.search, color: Colors.white),
                  label: const Text('SCAN ECU', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: _isScanning ? null : _scanForCodes,
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  icon: const Icon(Icons.delete_forever, color: Colors.white),
                  label: const Text('CLEAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: (_isScanning || !_hasScanned || _troubleCodes.isEmpty) ? null : _clearCodes,
                ),
              ],
            ),
          ),
          
          // Results Area
          Expanded(
            child: !_hasScanned
                ? const Center(child: Text("Tap 'SCAN ECU' to read vehicle codes.", style: TextStyle(color: Colors.white54, fontSize: 16)))
                : _troubleCodes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
                            SizedBox(height: 16),
                            Text("No Trouble Codes Found", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            Text("Your vehicle system is clean.", style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _troubleCodes.length,
                        itemBuilder: (context, index) {
                          String code = _troubleCodes[index];
                          String description = _dtcDictionary[code] ?? "Unknown generic or manufacturer-specific code.";
                          
                          return Card(
                            color: const Color(0xFF2A1215), // Slight red tint for errors
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.redAccent, width: 1)),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 36),
                              title: Text(code, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                              subtitle: Text(description, style: const TextStyle(color: Colors.white70)),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}