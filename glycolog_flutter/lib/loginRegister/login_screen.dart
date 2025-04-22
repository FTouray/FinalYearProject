import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscureText = true; // Track password visibility
  String? errorMessage;
  final String? apiUrl = dotenv.env['API_URL'];


  Future<void> resetOnboardingStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboardingCompleted');
    print('Onboarding status reset for testing.');
  }

  Future<String?> getAccessToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }


  Future<void> login() async {
    String username = usernameController.text;
    String password = passwordController.text;

    // Check if fields are empty
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Both username and password are required.';
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/login/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String firstName = data['first_name']; // API returns the first name
        String username = data['username'];
        String accessToken = data['access']; // Get the access token
        String refreshToken = data['refresh']; // Get the refresh token

        // Store the access token and refresh token in shared preferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken);
        await prefs.setString('refresh_token', refreshToken);
        await prefs.setString('first_name', firstName);
        await prefs.setString('username', username);

        setState(() {
          errorMessage = null; // Clear error if login is successful
        });

    
        Future.microtask(() {
          bool onboardingCompleted =
              prefs.getBool('onboardingCompleted') ?? false;

          if (!mounted) return;

          if (onboardingCompleted) {
            Navigator.pushNamedAndRemoveUntil(
                context, '/home', (route) => false,
                arguments: firstName);
          } else {
            Navigator.pushNamedAndRemoveUntil(
                context, '/onboarding', (route) => false);
          }
        });

      } else {
        final data = json.decode(response.body);
        setState(() {
          errorMessage = data['error'] ?? 'Login failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred. Please try again.';
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                Image.asset(
                  'assets/logos/glycolog_logo.png',
                  height: 100,
                ),
                const SizedBox(height: 20),
                // Card Container for login form
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  elevation: 8.0,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Username Field
                        TextField(
                          controller: usernameController,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Password Field with show/hide option
                        TextField(
                          controller: passwordController,
                          obscureText: _obscureText,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureText
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.blue[800],
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureText = !_obscureText;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Error Message Display
                        if (errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        const SizedBox(height: 20),
                        // Login Button
                        ElevatedButton(
                          onPressed: login,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 50, vertical: 15),
                            backgroundColor: Colors.blue[800],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Register Link
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: Text(
                    "Don't have an account? Register",
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
