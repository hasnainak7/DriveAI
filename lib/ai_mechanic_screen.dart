
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AiMechanicScreen extends StatefulWidget {
  final Map<String, dynamic> activeVehicle;
  final List<String> dtcCodes;

  const AiMechanicScreen({super.key, required this.activeVehicle, required this.dtcCodes});

  @override
  State<AiMechanicScreen> createState() => _AiMechanicScreenState();
}

class _AiMechanicScreenState extends State<AiMechanicScreen> {
  final List<Map<String, String>> _chatHistory = [];
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;
  
  // REMEMBER TO KEEP YOUR CORRECT IP ADDRESS HERE!
  final String _apiUrl = "http://192.168.100.25:8000/mechanic/chat"; 

  // Pre-defined Quick Action Questions
  final List<String> _suggestedQuestions = [
    "اس کے اسباب کیا ہیں؟ (Causes)",
    "اس کا حل کیا ہے؟ (Fixes)",
    "کیا گاڑی چلانا محفوظ ہے؟ (Safe to drive?)",
  ];

  @override
  void initState() {
    super.initState();
    _requestInitialDiagnostic();
  }

  Future<void> _sendMessageToAI(String userMessage) async {
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "car_year": widget.activeVehicle['year'],
          "car_make": widget.activeVehicle['make'],
          "car_model": widget.activeVehicle['model'],
          "dtc_codes": widget.dtcCodes,
          "user_message": userMessage, // For pre-defined questions, this sends the Urdu text
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _chatHistory.add({"sender": "ai", "text": data['reply']});
        });
      } else {
        setState(() {
          _chatHistory.add({"sender": "ai", "text": "معذرت، سرور سے رابطہ نہیں ہو سکا۔ (Server Connection Error)"});
        });
      }
    } catch (e) {
      setState(() {
         _chatHistory.add({"sender": "ai", "text": "معذرت، نیٹ ورک کا مسئلہ ہے۔ (Network Error)"});
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _requestInitialDiagnostic() {
    setState(() {
      _chatHistory.add({"sender": "system", "text": "Analyzing your ${widget.activeVehicle['make']} for codes: ${widget.dtcCodes.join(', ')}..."});
    });
    _sendMessageToAI(""); 
  }

  void _handleUserSubmit() {
    if (_messageController.text.trim().isEmpty) return;
    
    String message = _messageController.text.trim();
    setState(() {
      _chatHistory.add({"sender": "user", "text": message});
      _messageController.clear();
    });
    
    _sendMessageToAI(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('AI Mechanic', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _chatHistory.length,
              itemBuilder: (context, index) {
                final chat = _chatHistory[index];
                bool isUser = chat['sender'] == 'user';
                bool isSystem = chat['sender'] == 'system';

                if (isSystem) {
                  return Center(child: Padding(padding: const EdgeInsets.all(8.0), child: Text(chat['text']!, style: const TextStyle(color: Colors.cyan))));
                }

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.cyan.withOpacity(0.2) : const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isUser ? Colors.cyan : Colors.white24),
                    ),
                    child: Text(
                      chat['text']!,
                      style: TextStyle(color: Colors.white, fontSize: isUser ? 16 : 18, height: 1.5),
                      textDirection: isUser ? TextDirection.ltr : TextDirection.rtl, 
                    ),
                  ),
                );
              },
            ),
          ),
          
          if (_isLoading) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Colors.cyan)),
          
          // ---> NEW: Quick Action Chips Row <---
          if (!_isLoading)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: _suggestedQuestions.map((question) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      backgroundColor: const Color(0xFF1E1E1E),
                      side: const BorderSide(color: Colors.cyan),
                      labelStyle: const TextStyle(color: Colors.white),
                      label: Text(question),
                      onPressed: () {
                        // When tapped, put the text in the box and submit it
                        _messageController.text = question;
                        _handleUserSubmit();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

          // Chat Input Field
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E1E1E),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Type a question...",
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.cyan,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.black),
                    onPressed: _isLoading ? null : _handleUserSubmit,
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}