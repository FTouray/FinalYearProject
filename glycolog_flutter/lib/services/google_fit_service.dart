// ignore_for_file: avoid_print

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleFitService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/fitness.activity.read'],
  );

  /// **Sign in with Google Fit and link the account**
  Future<bool> signInWithGoogleFit() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser != null) {
        print("Google Fit connected: ${googleUser.email}");
        bool success = await sendGoogleFitEmail(googleUser.email);
        return success;
      } else {
        print("User canceled Google Fit sign-in.");
        return false;
      }
    } catch (error) {
      print("Error during Google Fit sign-in: $error");
      return false;
    }
  }

  /// **Send Google Fit email to backend for linking**
  Future<bool> sendGoogleFitEmail(String email) async {
    try {
      final String? apiUrl = dotenv.env['API_URL'];
      if (apiUrl == null || apiUrl.isEmpty) {
        print("API_URL is not set in the .env file.");
        return false;
      }

      final String? token = await AuthService().getAccessToken();
      if (token == null) {
        print("User is not authenticated.");
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
