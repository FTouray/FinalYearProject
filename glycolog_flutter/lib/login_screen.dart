import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String? errorMessage;

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
        Uri.parse('http://10.0.2.2:8000/api/login/'),  // Adjust this for the actual address
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Login successful: ${data['message']}');
        setState(() {
          errorMessage = null;  // Clear error if login is successful
        });
        // Navigate to the next page or do something else
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: login,
              child: Text('Login'),
            ),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
