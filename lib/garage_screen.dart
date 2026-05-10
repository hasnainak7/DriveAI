// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// // Your custom file imports
// import 'main.dart'; // To access the global supabase client
// import 'add_vehicle_screen.dart'; // To navigate to add more cars
// import 'guardian_screen.dart'; // The Sprint 8 addition for remote monitoring

// class GarageScreen extends StatefulWidget {
//   const GarageScreen({super.key});

//   @override
//   State<GarageScreen> createState() => _GarageScreenState();
// }

// class _GarageScreenState extends State<GarageScreen> {
//   List<dynamic> _vehicles = [];
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _fetchVehicles();
//   }

//   // Fetch the data from Supabase
//   Future<void> _fetchVehicles() async {
//     setState(() => _isLoading = true);
//     try {
//       // The RLS policy guarantees they only get their own cars
//       final data = await supabase.from('vehicles').select('*');
//       setState(() {
//         _vehicles = data;
//       });
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Failed to load vehicles'), backgroundColor: Colors.red),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }


//   // ---> ADD THIS FUNCTION <---
//   Future<void> _deleteVehicle(String vehicleId, String make, String model) async {
//     // 1. Show a confirmation dialog first
//     bool confirm = await showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: const Color(0xFF1E1E1E),
//         title: const Text('Delete Vehicle?', style: TextStyle(color: Colors.white)),
//         content: Text('Are you sure you want to remove the $make $model from your garage? This will also delete its maintenance logs.', style: const TextStyle(color: Colors.white70)),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
//             onPressed: () => Navigator.pop(context, true), 
//             child: const Text('DELETE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
//           ),
//         ],
//       )
//     ) ?? false;

//     if (!confirm) return;

//     // 2. Delete from Supabase
//     try {
//       await supabase.from('vehicles').delete().eq('id', vehicleId);
//       _fetchVehicles(); // Refresh the list
//       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vehicle removed from garage.'), backgroundColor: Colors.redAccent));
//     } catch (e) {
//       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting vehicle: $e')));
//     }
//   }


//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF121212),
//       appBar: AppBar(
//         title: const Text('My Garage', style: TextStyle(color: Colors.white)),
//         backgroundColor: Colors.black,
//         iconTheme: const IconThemeData(color: Colors.white),
//       ),
//       // A floating action button is a clean way to let users add more cars
//       floatingActionButton: FloatingActionButton(
//         backgroundColor: Colors.cyan,
//         child: const Icon(Icons.add, color: Colors.white),
//         onPressed: () async {
//           // Go to Add screen, and when we come back, refresh the list!
//           await Navigator.of(context).push(
//             MaterialPageRoute(builder: (context) => const AddVehicleScreen()),
//           );
//           _fetchVehicles(); 
//         },
//       ),
//       body: _isLoading 
//           ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
//           : _vehicles.isEmpty 
//               ? _buildEmptyState() 
//               : _buildVehicleList(),
//     );
//   }

//   // Professional UI: What to show if they have no cars yet
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.garage_outlined, size: 100, color: Colors.white.withOpacity(0.2)),
//           const SizedBox(height: 20),
//           const Text(
//             "Your garage is empty.",
//             style: TextStyle(color: Colors.white70, fontSize: 18),
//           ),
//           const SizedBox(height: 10),
//           const Text(
//             "Tap the + button to add your first vehicle.",
//             style: TextStyle(color: Colors.white54, fontSize: 14),
//           ),
//         ],
//       ),
//     );
//   }

//   // Build the list of cars
//   Widget _buildVehicleList() {
//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       itemCount: _vehicles.length,
//       itemBuilder: (context, index) {
//         final vehicle = _vehicles[index];
//         return Card(
//           color: const Color(0xFF1E1E1E),
//           elevation: 4,
//           margin: const EdgeInsets.only(bottom: 16),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           child: ListTile(
//             contentPadding: const EdgeInsets.all(16),
//             leading: const CircleAvatar(
//               backgroundColor: Colors.cyan,
//               child: Icon(Icons.directions_car, color: Colors.white),
//             ),
//             title: Text(
//               "${vehicle['year']} ${vehicle['make']} ${vehicle['model']}",
//               style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             subtitle: Text(
//               "VIN: ${vehicle['vin_number'] ?? 'Not provided'}",
//               style: const TextStyle(color: Colors.white54),
//             ),
            
//             // ---> SPRINT 8 UPDATED TRAILING BUTTONS <---
           


//             trailing: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // 1. Remote Monitor Button (The Guardian Portal)
//                 IconButton(
//                   tooltip: 'Remote Monitor',
//                   icon: const Icon(Icons.satellite_alt, color: Colors.orange),
//                   onPressed: () {
//                     Navigator.of(context).push(
//                       MaterialPageRoute(
//                         builder: (context) => GuardianScreen(vehicle: vehicle),
//                       ),
//                     );
//                   },
//                 ),
//                 // 2. Drive / Select Button
//                 IconButton(
//                   tooltip: 'Set as Active Vehicle',
//                   icon: const Icon(Icons.chevron_right, color: Colors.cyan),
//                   onPressed: () {
//                     Navigator.pop(context, vehicle);
//                   },
//                 ),
//               ],
//             ),
//             // Tapping the card itself acts as the "Select Active" button too
//             onTap: () {
//               Navigator.pop(context, vehicle);
//             },
//           ),
//         );
//       },
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Your custom file imports
import 'main.dart'; // To access the global supabase client
import 'add_vehicle_screen.dart'; // To navigate to add more cars
import 'guardian_screen.dart'; // The Sprint 8 addition for remote monitoring

class GarageScreen extends StatefulWidget {
  const GarageScreen({super.key});

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  List<dynamic> _vehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
  }

  // Fetch the data from Supabase (Using your original, working query!)
  Future<void> _fetchVehicles() async {
    setState(() => _isLoading = true);
    try {
      // The RLS policy guarantees they only get their own cars
      final data = await supabase.from('vehicles').select('*');
      setState(() {
        _vehicles = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load vehicles'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---> NEW DELETE FUNCTION <---
  Future<void> _deleteVehicle(String vehicleId, String make, String model) async {
    // 1. Show a confirmation dialog first
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Vehicle?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to remove the $make $model from your garage? This will also delete its maintenance logs.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('DELETE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      )
    ) ?? false;

    if (!confirm) return;

    // 2. Delete from Supabase
    try {
      await supabase.from('vehicles').delete().eq('id', vehicleId);
      _fetchVehicles(); // Refresh the list
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vehicle removed from garage.'), backgroundColor: Colors.redAccent));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting vehicle: $e'), backgroundColor: Colors.red));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('My Garage', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // A floating action button is a clean way to let users add more cars
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyan,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          // Go to Add screen, and when we come back, refresh the list!
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddVehicleScreen()),
          );
          _fetchVehicles(); 
        },
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
          : _vehicles.isEmpty 
              ? _buildEmptyState() 
              : _buildVehicleList(),
    );
  }

  // Professional UI: What to show if they have no cars yet
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.garage_outlined, size: 100, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 20),
          const Text(
            "Your garage is empty.",
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 10),
          const Text(
            "Tap the + button to add your first vehicle.",
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // Build the list of cars
  Widget _buildVehicleList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _vehicles.length,
      itemBuilder: (context, index) {
        final vehicle = _vehicles[index];
        return Card(
          color: const Color(0xFF1E1E1E),
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const CircleAvatar(
              backgroundColor: Colors.cyan,
              child: Icon(Icons.directions_car, color: Colors.white),
            ),
            title: Text(
              "${vehicle['year']} ${vehicle['make']} ${vehicle['model']}",
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "VIN: ${vehicle['vin_number'] ?? 'Not provided'}",
              style: const TextStyle(color: Colors.white54),
            ),
            
            // ---> UPDATED TRAILING BUTTONS (Now includes Delete) <---
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Delete Button (NEW)
                IconButton(
                  tooltip: 'Delete Vehicle',
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _deleteVehicle(vehicle['id'].toString(), vehicle['make'], vehicle['model']),
                ),
                // 2. Remote Monitor Button (The Guardian Portal)
                IconButton(
                  tooltip: 'Remote Monitor',
                  icon: const Icon(Icons.satellite_alt, color: Colors.orange),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => GuardianScreen(vehicle: vehicle),
                      ),
                    );
                  },
                ),
                // 3. Drive / Select Button
                IconButton(
                  tooltip: 'Set as Active Vehicle',
                  icon: const Icon(Icons.chevron_right, color: Colors.cyan),
                  onPressed: () {
                    Navigator.pop(context, vehicle);
                  },
                ),
              ],
            ),
            // Tapping the card itself acts as the "Select Active" button too
            onTap: () {
              Navigator.pop(context, vehicle);
            },
          ),
        );
      },
    );
  }
}