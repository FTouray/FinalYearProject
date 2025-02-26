import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController passwordConfirmController =
      TextEditingController();
  bool _obscurePassword = true; // Password visibility for password field
  bool _obscurePasswordConfirm =
      true; // Password visibility for confirm password field
  String? errorMessage;
  final String? apiUrl = dotenv.env['API_URL']; 
  final String? oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID'];
  final String? oneSignalApiKey = dotenv.env['ONESIGNAL_API_KEY'];

  Future<void> register() async {
    // Gather data from form fields
    String username = usernameController.text;
    String email = emailController.text;
    String phone = phoneController.text;
    String firstName = firstNameController.text;
    String lastName = lastNameController.text;
    String password = passwordController.text;
    String passwordConfirm = passwordConfirmController.text;

    // Frontend validation for blank fields
    if ([username, email, phone, firstName, lastName, password, passwordConfirm]
        .any((field) => field.isEmpty)) {
      setState(() {
        errorMessage = 'All fields are required.';
      });
      return;
    }

    // Check if passwords match
    if (password != passwordConfirm) {
      setState(() {
        errorMessage = 'Passwords do not match.';
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/register/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'phone_number': phone,
          'first_name': firstName,
          'last_name': lastName,
          'password': password,
          'password2': passwordConfirm,
        }),
      );

      if (response.statusCode == 201) {
        setState(() {
          errorMessage = null; // Clear error if registration is successful
        });
        print('User registered successfully!');
        
        final responseData = json.decode(response.body);
        String accessToken = responseData['access']; // Get access token

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken);

         await fetchOneSignalPlayerId(accessToken);

        // Navigate back to the login screen after successful registration
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        final data = json.decode(response.body);
        setState(() {
          errorMessage = data['error'];
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred. Please try again.';
      });
    }
  }

     Future<void> fetchOneSignalPlayerId(String accessToken) async {
    final response = await http.get(
      Uri.parse("https://onesignal.com/api/v1/players?app_id=$oneSignalAppId"),
      headers: {
        "Authorization": "Basic $oneSignalApiKey",
        "Content-Type": "application/json"
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> players = json.decode(response.body)['players'];

      if (players.isNotEmpty) {
        String playerId = players.first['id'];
        await sendPlayerIdToBackend(accessToken, playerId);
      }
    } else {
      print("Failed to fetch OneSignal Player ID: ${response.body}");
    }
  }

  Future<void> sendPlayerIdToBackend(
      String accessToken, String playerId) async {
    final response = await http.post(
      Uri.parse('$apiUrl/update-onesignal-player-id/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({"player_id": playerId}),
    );

    if (response.statusCode == 200) {
      print("OneSignal Player ID registered successfully.");
    } else {
      print("Failed to register OneSignal Player ID: ${response.body}");
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
                // Card Container for registration form
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
                          'Register',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // First Name Field
                        TextField(
                          controller: firstNameController,
                          decoration: InputDecoration(
                            labelText: 'First Name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Last Name Field
                        TextField(
                          controller: lastNameController,
                          decoration: InputDecoration(
                            labelText: 'Last Name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
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
                        // Email Field
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Phone Number Field
                        TextField(
                          controller: phoneController,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Password Field with show/hide icon
                        TextField(
                          controller: passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.blue[800],
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Confirm Password Field with show/hide icon
                        TextField(
                          controller: passwordConfirmController,
                          obscureText: _obscurePasswordConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePasswordConfirm
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.blue[800],
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePasswordConfirm =
                                      !_obscurePasswordConfirm;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Register Button
                        ElevatedButton(
                          onPressed: register,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 50, vertical: 15),
                            backgroundColor: Colors.blue[800],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: const Text(
                            'Register',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
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
                        // Back to Login Option
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacementNamed(context,
                                '/login'); // Navigate back to login screen
                          },
                          child: Text(
                            'Back to Login',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
