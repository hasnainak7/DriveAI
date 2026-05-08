// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:intl/intl.dart';

// class MaintenanceScreen extends StatefulWidget {
//   final Map<String, dynamic> activeVehicle;

//   const MaintenanceScreen({super.key, required this.activeVehicle});

//   @override
//   State<MaintenanceScreen> createState() => _MaintenanceScreenState();
// }

// class _MaintenanceScreenState extends State<MaintenanceScreen> {
//   final _supabase = Supabase.instance.client;
//   List<Map<String, dynamic>> _logs = [];
//   bool _isLoading = true;
  
//   // Track the user's custom oil change threshold
//   int _currentThreshold = 5000; 

//   // Form Controllers for adding new records
//   final _costController = TextEditingController();
//   final _notesController = TextEditingController();
//   final _odometerController = TextEditingController();
//   String _selectedService = 'Oil Change';
//   DateTime _selectedDate = DateTime.now();

//   final List<String> _serviceTypes = [
//     'Oil Change', 'Brake Pad Replacement', 'Tire Rotation/Alignment',
//     'Battery Replacement', 'Air Filter', 'General Service', 'Other'
//   ];

//   @override
//   void initState() {
//     super.initState();
//     // Safely load the threshold, defaulting to 5000 if not set in DB yet
//     _currentThreshold = widget.activeVehicle['oil_change_threshold_km'] ?? 5000;
//     _fetchMaintenanceLogs();
//   }

//   Future<void> _fetchMaintenanceLogs() async {
//     setState(() => _isLoading = true);
//     try {
//       final response = await _supabase
//           .from('maintenance_logs')
//           .select()
//           .eq('vehicle_id', widget.activeVehicle['id'])
//           .order('service_date', ascending: false);
          
//       setState(() => _logs = List<Map<String, dynamic>>.from(response));
//     } catch (e) {
//       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading logs: $e'), backgroundColor: Colors.red));
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _addMaintenanceRecord() async {
//     if (_costController.text.isEmpty || _odometerController.text.isEmpty) return;

//     int currentOdo = int.parse(_odometerController.text);

//     try {
//       // 1. Save the record to the maintenance log
//       await _supabase.from('maintenance_logs').insert({
//         'vehicle_id': widget.activeVehicle['id'],
//         'service_type': _selectedService,
//         'cost': double.parse(_costController.text),
//         'odometer_km': currentOdo, // <--- SAVES THE ODOMETER
//         'service_date': _selectedDate.toIso8601String().split('T')[0],
//         'notes': _notesController.text.trim(),
//       });
      
//       // 2. If it's an Oil Change, RESET the notification baselines!
//       if (_selectedService == 'Oil Change') {
//         await _supabase.from('vehicles').update({
//           'last_oil_change_date': _selectedDate.toIso8601String().split('T')[0],
//           'last_oil_change_km': currentOdo // <--- RESETS THE DISTANCE COUNTER
//         }).eq('id', widget.activeVehicle['id']);
//       }
      
//       _costController.clear();
//       _notesController.clear();
//       _odometerController.clear(); // Clear the new field
//       _selectedDate = DateTime.now();
//       _selectedService = 'Oil Change';
      
//       if (mounted) {
//         Navigator.pop(context); 
//         _fetchMaintenanceLogs(); 
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record added!'), backgroundColor: Colors.green));
//       }
//     } catch (e) {
//       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving record: $e'), backgroundColor: Colors.red));
//     }
//   }

//   // Visual helper to give each service a unique color and icon
//   Map<String, dynamic> _getServiceStyle(String type) {
//     switch (type) {
//       case 'Oil Change': return {'icon': Icons.water_drop, 'color': Colors.amber};
//       case 'Brake Pad Replacement': return {'icon': Icons.stop_circle, 'color': Colors.redAccent};
//       case 'Tire Rotation/Alignment': return {'icon': Icons.tire_repair, 'color': Colors.cyan};
//       case 'Battery Replacement': return {'icon': Icons.battery_charging_full, 'color': Colors.green};
//       case 'Air Filter': return {'icon': Icons.air, 'color': Colors.lightBlue};
//       default: return {'icon': Icons.build, 'color': Colors.grey};
//     }
//   }

//   // ---> NEW: Threshold Editor Popup <---
//   void _showThresholdEditor() {
//     final TextEditingController thresholdController = TextEditingController(text: _currentThreshold.toString());

//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           backgroundColor: const Color(0xFF1E1E1E),
//           title: const Text('Set Oil Change Interval', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Text("How many kilometers before your next recommended oil change?", style: TextStyle(color: Colors.white70, fontSize: 14)),
//               const SizedBox(height: 16),
//               TextField(
//                 controller: thresholdController,
//                 keyboardType: TextInputType.number,
//                 style: const TextStyle(color: Colors.white),
//                 decoration: InputDecoration(
//                   labelText: 'Kilometers (e.g., 5000)',
//                   labelStyle: const TextStyle(color: Colors.cyan),
//                   suffixText: 'km',
//                   suffixStyle: const TextStyle(color: Colors.white54),
//                   filled: true,
//                   fillColor: Colors.black,
//                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
//                 ),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
//             ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
//               onPressed: () async {
//                 int? newVal = int.tryParse(thresholdController.text);
//                 if (newVal != null && newVal > 0) {
//                   try {
//                     // Update Supabase
//                     await _supabase.from('vehicles').update({'oil_change_threshold_km': newVal}).eq('id', widget.activeVehicle['id']);
//                     // Update UI
//                     setState(() => _currentThreshold = newVal);
                    
//                     if (context.mounted) {
//                       Navigator.pop(context);
//                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maintenance interval updated!'), backgroundColor: Colors.green));
//                     }
//                   } catch (e) {
//                     if (context.mounted) {
//                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
//                     }
//                   }
//                 }
//               },
//               child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
//             ),
//           ],
//         );
//       }
//     );
//   }

//   void _showAddRecordSheet() {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: const Color(0xFF1E1E1E),
//       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setModalState) {
//             return Padding(
//               padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   const Text("Log Maintenance", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
//                   const SizedBox(height: 20),
                  
//                   // Service Type Dropdown
//                   DropdownButtonFormField<String>(
//                     value: _selectedService,
//                     dropdownColor: const Color(0xFF2A2A2A),
//                     style: const TextStyle(color: Colors.white),
//                     decoration: InputDecoration(labelText: 'Service Type', labelStyle: const TextStyle(color: Colors.cyan), filled: true, fillColor: Colors.black, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
//                     items: _serviceTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
//                     onChanged: (val) => setModalState(() => _selectedService = val!),
//                   ),
//                   const SizedBox(height: 16),



//                   TextFormField(
//                     controller: _odometerController,
//                     keyboardType: TextInputType.number,
//                     style: const TextStyle(color: Colors.white),
//                     decoration: InputDecoration(
//                       labelText: 'Odometer Reading', 
//                       suffixText: 'km',
//                       suffixStyle: const TextStyle(color: Colors.white54),
//                       labelStyle: const TextStyle(color: Colors.cyan), 
//                       filled: true, 
//                       fillColor: Colors.black, 
//                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   // Cost & Date Row
//                   Row(
//                     children: [
//                       Expanded(
//                         child: TextFormField(
//                           controller: _costController,
//                           keyboardType: TextInputType.number,
//                           style: const TextStyle(color: Colors.white),
//                           decoration: InputDecoration(labelText: 'Cost (PKR)', prefixText: 'Rs. ', prefixStyle: const TextStyle(color: Colors.white54), labelStyle: const TextStyle(color: Colors.cyan), filled: true, fillColor: Colors.black, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
//                         ),
//                       ),
//                       const SizedBox(width: 16),
//                       Expanded(
//                         child: InkWell(
//                           onTap: () async {
//                             final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime.now(), builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Colors.cyan, onPrimary: Colors.black, surface: Color(0xFF1E1E1E), onSurface: Colors.white)), child: child!));
//                             if (picked != null) setModalState(() => _selectedDate = picked);
//                           },
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
//                             decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Text(DateFormat('MMM dd, yyyy').format(_selectedDate), style: const TextStyle(color: Colors.white)),
//                                 const Icon(Icons.calendar_month, color: Colors.cyan, size: 20),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 16),
                  
//                   // Notes
//                   TextFormField(
//                     controller: _notesController,
//                     style: const TextStyle(color: Colors.white),
//                     maxLines: 2,
//                     decoration: InputDecoration(labelText: 'Side Note / Mechanic Name', labelStyle: const TextStyle(color: Colors.cyan), filled: true, fillColor: Colors.black, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
//                   ),
//                   const SizedBox(height: 24),
                  
//                   // Submit Button
//                   ElevatedButton(
//                     style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
//                     onPressed: _addMaintenanceRecord,
//                     child: const Text('SAVE RECORD', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
//                   ),
//                   const SizedBox(height: 24),
//                 ],
//               ),
//             );
//           }
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF121212),
//       appBar: AppBar(
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text('Service History', style: TextStyle(color: Colors.white)),
//             Text('${widget.activeVehicle['year']} ${widget.activeVehicle['make']} ${widget.activeVehicle['model']}', style: const TextStyle(color: Colors.cyan, fontSize: 12)),
//           ],
//         ),
//         backgroundColor: Colors.black,
//         iconTheme: const IconThemeData(color: Colors.white),
//       ),
//       body: Column(
//         children: [
//           // ---> NEW: Settings Banner <---
//           Container(
//             padding: const EdgeInsets.all(16),
//             color: const Color(0xFF1E1E1E),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text("Oil Change Reminder At", style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1)),
//                     const SizedBox(height: 4),
//                     Text("$_currentThreshold km", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
//                   ],
//                 ),
//                 TextButton.icon(
//                   onPressed: _showThresholdEditor,
//                   icon: const Icon(Icons.edit, color: Colors.cyan, size: 18),
//                   label: const Text("EDIT", style: TextStyle(color: Colors.cyan)),
//                 )
//               ],
//             ),
//           ),
          
//           const Divider(height: 1, color: Colors.white12),

//           // ---> Existing Logs List <---
//           Expanded(
//             child: _isLoading 
//               ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
//               : _logs.isEmpty 
//                 ? Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(Icons.history_edu, size: 80, color: Colors.white.withOpacity(0.2)),
//                         const SizedBox(height: 16),
//                         const Text("No Service Records Found", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
//                         const Text("Keep track of your oil changes and repairs here.", style: TextStyle(color: Colors.white54)),
//                       ],
//                     ),
//                   )
//                 : ListView.builder(
//                     padding: const EdgeInsets.all(16),
//                     itemCount: _logs.length,
//                     itemBuilder: (context, index) {
//                       final log = _logs[index];
//                       final style = _getServiceStyle(log['service_type']);
//                       final date = DateTime.parse(log['service_date']);

//                       return Container(
//                         margin: const EdgeInsets.only(bottom: 16),
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: const Color(0xFF1E1E1E),
//                           borderRadius: BorderRadius.circular(16),
//                           border: Border.all(color: Colors.white.withOpacity(0.05)),
//                         ),
//                         child: Row(
//                           children: [
//                             Container(
//                               padding: const EdgeInsets.all(12),
//                               decoration: BoxDecoration(color: style['color'].withOpacity(0.1), shape: BoxShape.circle),
//                               child: Icon(style['icon'], color: style['color'], size: 28),
//                             ),
//                             const SizedBox(width: 16),
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(log['service_type'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
//                                   const SizedBox(height: 4),

//                                   Row(
//                                     children: [
//                                       Text(DateFormat('MMMM dd, yyyy').format(date), style: const TextStyle(color: Colors.white54, fontSize: 12)),
//                                       const SizedBox(width: 8),
//                                       if (log['odometer_km'] != null && log['odometer_km'] > 0)
//                                         Container(
//                                           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                                           decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
//                                           child: Text("${log['odometer_km']} km", style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
//                                         )
//                                     ],
//                                   ),
                                  
//                                   if (log['notes'] != null && log['notes'].toString().isNotEmpty) ...[
//                                     const SizedBox(height: 8),
//                                     Text(log['notes'], style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 13)),
//                                   ]
//                                 ],
//                               ),
//                             ),
//                             Column(
//                               crossAxisAlignment: CrossAxisAlignment.end,
//                               children: [
//                                 const Text("COST", style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1)),
//                                 Text("Rs. ${log['cost']}", style: const TextStyle(color: Colors.cyan, fontSize: 16, fontWeight: FontWeight.bold)),
//                               ],
//                             )
//                           ],
//                         ),
//                       );
//                     },
//                   ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton.extended(
//         backgroundColor: Colors.cyan,
//         icon: const Icon(Icons.add, color: Colors.black),
//         label: const Text("ADD RECORD", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
//         onPressed: _showAddRecordSheet,
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MaintenanceScreen extends StatefulWidget {
  final Map<String, dynamic> activeVehicle;
  final int currentOdometer;

  const MaintenanceScreen({
    super.key, 
    required this.activeVehicle, 
    required this.currentOdometer
  });

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  
  // Track the user's custom oil change threshold
  int _currentThreshold = 5000; 

  // Form Controllers for adding new records
  final _costController = TextEditingController();
  final _notesController = TextEditingController();
  final _odometerController = TextEditingController(); 
  String _selectedService = 'Oil Change';
  DateTime _selectedDate = DateTime.now();

  final List<String> _serviceTypes = [
    'Oil Change', 'Brake Pad Replacement', 'Tire Rotation/Alignment',
    'Battery Replacement', 'Air Filter', 'General Service', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    // Safely load the threshold, defaulting to 5000 if not set in DB yet
    _currentThreshold = widget.activeVehicle['oil_change_threshold_km'] ?? 5000;
    
    // Auto-fill the odometer text box if we received live data from the OBD scanner!
    if (widget.currentOdometer > 0) {
      _odometerController.text = widget.currentOdometer.toString();
    }
    
    _fetchMaintenanceLogs();
  }

  Future<void> _fetchMaintenanceLogs() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('maintenance_logs')
          .select()
          .eq('vehicle_id', widget.activeVehicle['id'])
          .order('service_date', ascending: false);
          
      setState(() => _logs = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading logs: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addMaintenanceRecord() async {
    if (_costController.text.isEmpty || _odometerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in Cost and Odometer!'), backgroundColor: Colors.red));
      return;
    }

    int currentOdo = int.tryParse(_odometerController.text) ?? 0;

    try {
      // 1. Save the record to the maintenance log
      await _supabase.from('maintenance_logs').insert({
        'vehicle_id': widget.activeVehicle['id'],
        'service_type': _selectedService,
        'cost': double.parse(_costController.text),
        'odometer_km': currentOdo,
        'service_date': _selectedDate.toIso8601String().split('T')[0],
        'notes': _notesController.text.trim(),
      });
      
      // 2. If it's an Oil Change, RESET the background notification baselines!
      if (_selectedService == 'Oil Change') {
        await _supabase.from('vehicles').update({
          'last_oil_change_date': _selectedDate.toIso8601String().split('T')[0],
          'last_oil_change_km': currentOdo 
        }).eq('id', widget.activeVehicle['id']);
      }
      
      _costController.clear();
      _notesController.clear();
      // Keep the odometer controller as-is in case they want to add two things at once
      _selectedDate = DateTime.now();
      _selectedService = 'Oil Change';
      
      if (mounted) {
        Navigator.pop(context); // Close the bottom sheet
        _fetchMaintenanceLogs(); // Refresh the list
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record added successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving record: $e'), backgroundColor: Colors.red));
    }
  }

  // Visual helper to give each service a unique color and icon
  Map<String, dynamic> _getServiceStyle(String type) {
    switch (type) {
      case 'Oil Change': return {'icon': Icons.water_drop, 'color': Colors.amber};
      case 'Brake Pad Replacement': return {'icon': Icons.stop_circle, 'color': Colors.redAccent};
      case 'Tire Rotation/Alignment': return {'icon': Icons.tire_repair, 'color': Colors.cyan};
      case 'Battery Replacement': return {'icon': Icons.battery_charging_full, 'color': Colors.green};
      case 'Air Filter': return {'icon': Icons.air, 'color': Colors.lightBlue};
      default: return {'icon': Icons.build, 'color': Colors.grey};
    }
  }

  // ---> Threshold Editor Popup <---
  void _showThresholdEditor() {
    final TextEditingController thresholdController = TextEditingController(text: _currentThreshold.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Set Oil Change Interval', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("How many kilometers before your next recommended oil change?", style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 16),
              TextField(
                controller: thresholdController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Kilometers (e.g., 5000)',
                  labelStyle: const TextStyle(color: Colors.cyan),
                  suffixText: 'km',
                  suffixStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              onPressed: () async {
                int? newVal = int.tryParse(thresholdController.text);
                if (newVal != null && newVal > 0) {
                  try {
                    await _supabase.from('vehicles').update({'oil_change_threshold_km': newVal}).eq('id', widget.activeVehicle['id']);
                    setState(() => _currentThreshold = newVal);
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maintenance interval updated!'), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    }
                  }
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
  }

  void _showAddRecordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom, 
                left: 24, right: 24, top: 24
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Log Maintenance", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  // Service Type Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedService,
                    dropdownColor: const Color(0xFF2A2A2A),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: 'Service Type', labelStyle: const TextStyle(color: Colors.cyan), filled: true, fillColor: Colors.black, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    items: _serviceTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                    onChanged: (val) => setModalState(() => _selectedService = val!),
                  ),
                  const SizedBox(height: 16),

                  // Odometer Reading
                  TextFormField(
                    controller: _odometerController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Odometer Reading', 
                      suffixText: 'km',
                      suffixStyle: const TextStyle(color: Colors.white54),
                      labelStyle: const TextStyle(color: Colors.cyan), 
                      filled: true, 
                      fillColor: Colors.black, 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Cost & Date Row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _costController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(labelText: 'Cost (PKR)', prefixText: 'Rs. ', prefixStyle: const TextStyle(color: Colors.white54), labelStyle: const TextStyle(color: Colors.cyan), filled: true, fillColor: Colors.black, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context, 
                              initialDate: _selectedDate, 
                              firstDate: DateTime(2000), 
                              lastDate: DateTime.now(), 
                              builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Colors.cyan, onPrimary: Colors.black, surface: Color(0xFF1E1E1E), onSurface: Colors.white)), child: child!)
                            );
                            if (picked != null) setModalState(() => _selectedDate = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(DateFormat('MMM dd, yyyy').format(_selectedDate), style: const TextStyle(color: Colors.white)),
                                const Icon(Icons.calendar_month, color: Colors.cyan, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Notes
                  TextFormField(
                    controller: _notesController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: InputDecoration(labelText: 'Side Note / Mechanic Name', labelStyle: const TextStyle(color: Colors.cyan), filled: true, fillColor: Colors.black, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 24),
                  
                  // Submit Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: _addMaintenanceRecord,
                    child: const Text('SAVE RECORD', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Service History', style: TextStyle(color: Colors.white)),
            Text('${widget.activeVehicle['year']} ${widget.activeVehicle['make']} ${widget.activeVehicle['model']}', style: const TextStyle(color: Colors.cyan, fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ---> Settings Banner <---
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E1E1E),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Oil Change Reminder At", style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text("$_currentThreshold km", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                TextButton.icon(
                  onPressed: _showThresholdEditor,
                  icon: const Icon(Icons.edit, color: Colors.cyan, size: 18),
                  label: const Text("EDIT", style: TextStyle(color: Colors.cyan)),
                )
              ],
            ),
          ),
          
          const Divider(height: 1, color: Colors.white12),

          // ---> Existing Logs List <---
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
              : _logs.isEmpty 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_edu, size: 80, color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        const Text("No Service Records Found", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const Text("Keep track of your oil changes and repairs here.", style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final style = _getServiceStyle(log['service_type']);
                      final date = DateTime.parse(log['service_date']);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: style['color'].withOpacity(0.1), shape: BoxShape.circle),
                              child: Icon(style['icon'], color: style['color'], size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(log['service_type'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  
                                  // ---> Date & Odometer Row <---
                                  Row(
                                    children: [
                                      Text(DateFormat('MMM dd, yyyy').format(date), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                      const SizedBox(width: 8),
                                      if (log['odometer_km'] != null && log['odometer_km'] > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
                                          child: Text("${log['odometer_km']} km", style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                                        )
                                    ],
                                  ),

                                  if (log['notes'] != null && log['notes'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(log['notes'], style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 13)),
                                  ]
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text("COST", style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1)),
                                Text("Rs. ${log['cost']}", style: const TextStyle(color: Colors.cyan, fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.cyan,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text("ADD RECORD", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        onPressed: _showAddRecordSheet,
      ),
    );
  }
}