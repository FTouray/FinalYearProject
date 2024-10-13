import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegisterScreen extends StatefulWidget {
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
  final TextEditingController passwordConfirmController = TextEditingController();
  String? errorMessage;

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
    if ([username, email, phone, firstName, lastName, password, passwordConfirm].any((field) => field.isEmpty)) {
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
        Uri.parse('http://10.0.2.2:8000/api/register/'),  // Adjust this for the actual address
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'phone_number': phone,
          'first_name': firstName,
          'last_name': lastName,
          'password1': password,
          'password2': passwordConfirm,
        }),
      );

      if (response.statusCode == 201) {
        setState(() {
          errorMessage = null;  // Clear error if registration is successful
        });
        print('User registered successfully!');
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
      appBar: AppBar(title: Text('Register')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: firstNameController,
              decoration: InputDecoration(labelText: 'First Name'),
            ),
            TextField(
              controller: lastNameController,
              decoration: InputDecoration(labelText: 'Last Name'),
            ),
            TextField(
              controller: usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(labelText: 'Phone Number'),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            TextField(
              controller: passwordConfirmController,
              decoration: InputDecoration(labelText: 'Confirm Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: register,
              child: Text('Register'),
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
