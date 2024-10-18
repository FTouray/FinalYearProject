import 'package:flutter/material.dart';
import 'glucoseLog/add_glucose_log_screen.dart';
import 'glucoseLog/gL_history_screen.dart';
import 'glucoseLog/gl_detail_screen.dart';
import 'glucoseLog/glucose_log_screen.dart';
import 'loginRegister/login_screen.dart';
import 'home/homepage_screen.dart';
import 'loginRegister/register_screen.dart';
import 'home/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure bindings are initialized
  final darkMode = await _loadDarkModePreference(); // Load dark mode preference before running app
  final token = await _loadToken(); // Load token from SharedPreferences
  runApp(MyApp(darkModeEnabled: darkMode, token: token)); // Pass dark mode state and token to MyApp
}

// Function to load dark mode preference from SharedPreferences
Future<bool> _loadDarkModePreference() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('darkModeEnabled') ?? false; // Return saved dark mode preference or default to false
}

// Function to load token from SharedPreferences
Future<String?> _loadToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('auth_token'); // Return the stored token
}

class MyApp extends StatefulWidget {
  final bool darkModeEnabled;
  final String? token;

  const MyApp({super.key, required this.darkModeEnabled, this.token});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  String? _token;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.darkModeEnabled; // Initialize dark mode from passed preference
    _token = widget.token; // Initialize token
  }

  // Method to toggle dark mode across the app
  void _toggleDarkMode(bool isEnabled) {
    setState(() {
      _isDarkMode = isEnabled;
    });
    _saveDarkModePreference(isEnabled); // Save dark mode preference when toggled
  }

  // Save dark mode preference in SharedPreferences
  Future<void> _saveDarkModePreference(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkModeEnabled', isEnabled); // Save the user's dark mode preference
  }

  // Function to refresh the token
  Future<void> _refreshToken() async {
    final response = await http.post(
      Uri.parse('http://10.0.2.2:8000/api/token/refresh/'), // Your token refresh API endpoint
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'refresh': _token}), // Include refresh token in the body
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _token = data['access']; // Store the new access token
      await _saveToken(_token!); // Save the token to SharedPreferences
    } else {
      // Handle token refresh error
      print('Failed to refresh token: ${response.reasonPhrase}');
    }
  }

  // Save the token in SharedPreferences
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token); // Save the token for future use
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glycolog App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: _isDarkMode ? Brightness.dark : Brightness.light, // Apply dark mode dynamically
      ),
      initialRoute: _token != null ? '/home' : '/login', // Navigate based on token presence
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) {
          // Extract arguments (first name) passed during navigation
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is String) {
            return HomePage(firstName: args); // Pass first name to HomePage
          } else {
            return HomePage(firstName: 'User'); // Default name if argument is not found
          }
        },
        '/register': (context) => const RegisterScreen(),
        '/glucose-log': (context) => const GlucoseLogScreen(),
        '/settings': (context) => SettingsScreen(
              onToggleDarkMode: _toggleDarkMode, // Pass the toggle dark mode function to SettingsScreen
            ),
        '/add-log': (context) => const AddGlucoseLevelScreen(),
        '/log-history': (context) => const GlucoseLogHistoryScreen(),
         '/log-details': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return LogDetailsScreen(logDetails: args ?? {}); // Pass log details or an empty map
        },
      },
    );
  }
}
