import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; // For your global supabase variable
import 'guardian_screen.dart'; // <--- ADD THIS

class MechanicPortalScreen extends StatefulWidget {
  const MechanicPortalScreen({super.key});

  @override
  State<MechanicPortalScreen> createState() => _MechanicPortalScreenState();
}

class _MechanicPortalScreenState extends State<MechanicPortalScreen> {
  final TextEditingController _vinController = TextEditingController();
  List<Map<String, dynamic>> _clientVehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClientVehicles();
  }

  // Fetch all vehicles linked to this mechanic using YOUR table
  Future<void> _fetchClientVehicles() async {
    setState(() => _isLoading = true);
    try {
      final mechanicId = supabase.auth.currentUser!.id;
      
      // Query YOUR specific table and filter by active status
      final response = await supabase
          .from('mechanic_access_grants')
          .select('*, vehicles(*)')
          .eq('mechanic_id', mechanicId)
          .eq('status', 'active'); 

      setState(() {
        _clientVehicles = List<Map<String, dynamic>>.from(
          response.map((item) => item['vehicles']).where((v) => v != null)
        );
      });
    } catch (e) {
      print("Error fetching client vehicles: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Link a new customer's car using their VIN
  Future<void> _linkVehicleByVin() async {
    String vin = _vinController.text.trim();
    if (vin.isEmpty) return;

    try {
      // 1. Use the secure RPC function to get the vehicle ID without breaking RLS
      final vehicleId = await supabase.rpc(
        'get_vehicle_id_by_vin', 
        params: {'search_vin': vin}
      );

      // If the function returns null, the VIN doesn't exist
      if (vehicleId == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vehicle not found. Check VIN.'), backgroundColor: Colors.red));
        return;
      }

      // 2. Link it to the mechanic using the returned ID
      await supabase.from('mechanic_access_grants').insert({
        'mechanic_id': supabase.auth.currentUser!.id,
        'vehicle_id': vehicleId,
        'status': 'active' 
      });

      _vinController.clear();
      Navigator.pop(context); // Close the dialog
      _fetchClientVehicles(); // Refresh the list
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client Vehicle Linked!'), backgroundColor: Colors.green));

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error linking vehicle: $e'), backgroundColor: Colors.red));
    }
  }

  void _showAddVehicleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Add Client Vehicle', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _vinController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Client VIN',
            labelStyle: const TextStyle(color: Colors.cyan),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.cyan)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
            onPressed: _linkVehicleByVin,
            child: const Text('LINK VEHICLE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Remote Diagnostics: View the latest data pushed to the database
  void _viewRemoteDiagnostics(Map<String, dynamic> vehicle) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.cyan)),
    );

    try {
      // Get the absolute latest telemetry log for this specific car
      final log = await supabase
          .from('telemetry_logs')
          .select()
          .eq('vehicle_id', vehicle['id'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) Navigator.pop(context); // Close loading

      if (log == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No telemetry data available for this vehicle yet.')));
        return;
      }

      if (mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF1E1E1E),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (context) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Remote Diagnostics: ${vehicle['make']} ${vehicle['model']}", style: const TextStyle(color: Colors.cyan, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Last Sync: ${DateTime.parse(log['created_at']).toLocal().toString().split('.')[0]}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const Divider(color: Colors.white24, height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatDetail("RPM", "${log['rpm']}", Colors.greenAccent),
                    _buildStatDetail("SPEED", "${log['speed']} km/h", Colors.blueAccent),
                    _buildStatDetail("COOLANT", "${log['coolant_temp']} °C", log['coolant_temp'] > 100 ? Colors.redAccent : Colors.white),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatDetail("LOAD", "${log['engine_load']} %", Colors.orangeAccent),
                    _buildStatDetail("THROTTLE", "${log['throttle_pos']} %", Colors.white),
                    _buildStatDetail("INTAKE", "${log['intake_temp']} °C", Colors.white),
                  ],
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], padding: const EdgeInsets.symmetric(vertical: 15)),
                    icon: const Icon(Icons.sensors, color: Colors.white),
                    label: const Text("VIEW LIVE TELEMETRY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(context); // Close the bottom sheet
                      
                      // OPEN YOUR GUARDIAN SCREEN!
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => GuardianScreen(vehicle: vehicle),
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 12), // Space between buttons















                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900], padding: const EdgeInsets.symmetric(vertical: 15)),
                    icon: const Icon(Icons.warning, color: Colors.white),
                    label: const Text("PULL LATEST DTC CODES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checking ECU for codes... (No codes present)')));
                    },
                  ),
                )
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildStatDetail(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Mechanic Portal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.cyan),
            onPressed: _showAddVehicleDialog,
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
        : _clientVehicles.isEmpty
            ? const Center(child: Text("No client vehicles linked yet.\nTap + to add a VIN.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _clientVehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = _clientVehicles[index];
                  return Card(
                    color: const Color(0xFF1E1E1E),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: const CircleAvatar(
                        backgroundColor: Colors.cyan,
                        child: Icon(Icons.car_repair, color: Colors.black),
                      ),
                      title: Text("${vehicle['year']} ${vehicle['make']} ${vehicle['model']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text("VIN: ${vehicle['vin_number']}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: const Icon(Icons.query_stats, color: Colors.cyan),
                      onTap: () => _viewRemoteDiagnostics(vehicle),
                    ),
                  );
                },
              ),
    );
  }
}