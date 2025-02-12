import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GlucoseStepScreen extends StatefulWidget {
  const GlucoseStepScreen({Key? key}) : super(key: key);

  @override
  _GlucoseStepScreenState createState() => _GlucoseStepScreenState();
}

class _GlucoseStepScreenState extends State<GlucoseStepScreen> {
  final TextEditingController _glucoseController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  final String? apiUrl = dotenv.env['API_URL']; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Glucose Level'),
        backgroundColor: Colors.blue[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            LinearProgressIndicator(
              value: 0.5, // Progress for step 2 of 4
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[800]!),
            ),
            const SizedBox(height: 20),
            const Text(
              'Enter your glucose level:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _glucoseController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Glucose Level',
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Back',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final String glucoseLevel = _glucoseController.text;

    if (glucoseLevel.isEmpty || double.tryParse(glucoseLevel) == null) {
      setState(() {
        _isLoading = false;
        _error = 'Please enter a valid numeric glucose level.';
      });
      return;
    }

    try {
      // Fetch token and target range from shared preferences
      String? token = await AuthService().getAccessToken();

      if (token == null) {
        throw Exception('User is not authenticated.');
      }

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      double? targetMin = prefs.getDouble('targetMin');
      double? targetMax = prefs.getDouble('targetMax');

      if (targetMin == null || targetMax == null) {
        throw Exception(
            'Target range values are not set in shared preferences.');
      }

      final data = {
        'glucose_level': glucoseLevel,
        'target_min': targetMin.toString(),
        'target_max': targetMax.toString(),
      };

      final response = await http.post(
        Uri.parse('$apiUrl/questionnaire/glucose-step/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        Navigator.pushNamed(context, '/meal-step');
      } else {
        final error = jsonDecode(response.body);
        setState(() {
          _error = error['error'] ?? 'An error occurred.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'An error occurred: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
