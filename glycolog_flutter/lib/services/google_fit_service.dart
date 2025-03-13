// ignore_for_file: avoid_print
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleFitService {
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/fitness.activity.read',
    'https://www.googleapis.com/auth/fitness.body.read',
    'https://www.googleapis.com/auth/fitness.location.read',
    'https://www.googleapis.com/auth/fitness.heart_rate.read',
    'https://www.googleapis.com/auth/fitness.sleep.read',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _scopes,
  );

  /// **Sign in with Google Fit and link the account**
  Future<bool> signInWithGoogleFit() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print("User canceled Google Fit sign-in.");
        return false;
      }

      print("Google Fit connected: ${googleUser.email}");
      bool success = await sendGoogleFitEmail(googleUser.email);
      return success;
    } catch (error) {
      print("Error during Google Fit sign-in: $error");
      return false;
    }
  }

  /// **Send Google Fit email to backend for linking**
  Future<bool> sendGoogleFitEmail(String email) async {
    try {
      final String? apiUrl = dotenv.env['API_URL'];
      final String? token = await AuthService().getAccessToken();
      if (apiUrl == null || apiUrl.isEmpty || token == null) {
        print("API URL or token is missing.");
        return false;
      }

      final response = await http.post(
        Uri.parse('$apiUrl/link-google-fit/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'google_fit_email': email}),
      );

      if (response.statusCode == 200) {
        print("Google Fit account linked successfully!");
        return true;
      } else {
        print("Failed to link Google Fit: ${response.body}");
        return false;
      }
    } catch (error) {
      print("Error linking Google Fit: $error");
      return false;
    }
  }

  /// **Fetch Fitness Data from Google Fit**
  Future<Map<String, dynamic>?> fetchFitnessData() async {
    try {
      final String? apiUrl = dotenv.env['API_URL'];
      final String? token = await AuthService().getAccessToken();
      if (apiUrl == null || apiUrl.isEmpty || token == null) {
        print("API URL or token is missing.");
        return null;
      }

      final response = await http.get(
        Uri.parse('$apiUrl/fetch-google-fit-data/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Failed to fetch Google Fit data: ${response.body}");
        return null;
      }
    } catch (error) {
      print("Error fetching Google Fit data: $error");
      return null;
    }
  }

  /// **Check if Google Fit is already signed in**
  Future<bool> isGoogleFitSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  /// **Sign out from Google Fit**
  Future<void> signOutGoogleFit() async {
    await _googleSignIn.signOut();
    print("User signed out from Google Fit.");
  }
}
