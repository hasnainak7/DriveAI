import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';

// --- REPLACE THESE WITH YOUR ACTUAL SUPABASE KEYS ---
const supabaseUrl = 'https://jwyjutleaymzbkeucwkl.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp3eWp1dGxlYXltemJrZXVjd2tsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcwNzAyODEsImV4cCI6MjA5MjY0NjI4MX0.4Gzie8ZbXwCjEOZk7KqlBrlQVstjUL6rjUcCbYvi0cE';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase Connection
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const MyApp());
}

// Get a convenient reference to the database client
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Diagnostic',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      // Automatically route based on whether a session exists
      home: supabase.auth.currentSession == null
          ? const AuthScreen()
          : const HomeScreen(),
    );
  }
}

class InitializationScreen extends StatelessWidget {
  const InitializationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Init')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.car_repair, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'Foundation Connected.',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                // Test the connection logic here later
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Supabase is ready!')),
                );
              },
              child: const Text('Test Connection'),
            ),
          ],
        ),
      ),
    );
  }
}
