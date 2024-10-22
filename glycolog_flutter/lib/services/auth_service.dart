import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AuthService {
 // Function to get the access token from SharedPreferences
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token'); // Return the stored access token
  }

  // Function to refresh access token
  Future<void> refreshAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token'); // Retrieve refresh token

    try {
      final response = await http.post(
      //   Uri.parse('http://10.0.2.2:8000/api/token/refresh/'), // For Android Emulator
        Uri.parse('http://192.168.1.19:8000/api/token/refresh/'),  // For Physical Device 
      //  Uri.parse('http://147.252.148.38:8000/api/token/refresh/'), // For Eduroam API endpoint
      //  Uri.parse('http://192.168.40.184:8000/api/token/refresh/'), //Ethernet IP
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
        await prefs.setString('auth_token', newToken);
      } else {
        // Handle refresh token error
        print("Error refreshing token: ${response.reasonPhrase}");
      }
    } catch (e) {
      // Handle network or other errors
      print("Network error: $e");
    }
  }

  // Function to logout the user
  Future<void> logout() async {
    // Clear tokens from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }
}
