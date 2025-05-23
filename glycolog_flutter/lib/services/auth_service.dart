import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  final String? apiUrl = dotenv.env['API_URL']; 
  // Function to get the access token from SharedPreferences
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token'); // Return the stored access token
  }

  // Function to refresh access token
  Future<void> refreshAccessToken(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken =
        prefs.getString('refresh_token'); // Retrieve refresh token

    if (refreshToken == null) {
      print("No refresh token found");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/token/refresh/'), 
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'refresh': refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newToken = data['access']; // Get new access token

        // Store the new access token
        await prefs.setString('access_token', newToken);
        return newToken; // Return the new token
      } else if (response.statusCode == 401) {
        // Handle unauthorized error by clearing tokens and logging out
        if (context.mounted) {
          await logout(context);
        }
        print(
            "Unauthorized: Refresh token is invalid or expired. Logging out.");
      } else {
        // Handle other errors
        print("Error refreshing token: ${response.reasonPhrase}");
      }
    } catch (e) {
      // Handle network or other errors
      print("Network error: $e");
      return;
    }
  }

  // Function to logout the user
  Future<void> logout(BuildContext context) async {
    // Clear tokens from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');

    // Navigate to login screen if context is provided
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}
