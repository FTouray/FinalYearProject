// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String _selectedUnit = 'mg/dL'; // Default unit
  String _diabetesType = 'Type 1'; // Default diabetes type
  bool _isInsulinDependent = false; // Default insulin dependency

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedUnit', _selectedUnit);
    await prefs.setString('diabetesType', _diabetesType);
    await prefs.setBool('isInsulinDependent', _isInsulinDependent);
    await prefs.setBool('onboardingCompleted', true);

      // Debug: Log or print to ensure flag is set
    print('Onboarding Completed: true');
    // Mark onboarding as complete
    await prefs.setBool('onboardingCompleted', true);

    // Navigate to HomePage after saving preferences
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Your Preferences'),
        backgroundColor: Colors.blue[800],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Select Measurement Unit', Icons.straighten),
            ListTile(
              title: const Text('mg/dL'),
              leading: Radio<String>(
                value: 'mg/dL',
                groupValue: _selectedUnit,
                onChanged: (value) {
                  setState(() {
                    _selectedUnit = value!;
                  });
                },
                activeColor: Colors.blue[800],
              ),
            ),
            ListTile(
              title: const Text('mmol/L'),
              leading: Radio<String>(
                value: 'mmol/L',
                groupValue: _selectedUnit,
                onChanged: (value) {
                  setState(() {
                    _selectedUnit = value!;
                  });
                },
                activeColor: Colors.blue[800],
              ),
            ),
            const Divider(),
            _buildSectionHeader(
                'What Type of Diabetes Do You Have?', Icons.healing),
            ListTile(
              title: const Text('Type 1'),
              leading: Radio<String>(
                value: 'Type 1',
                groupValue: _diabetesType,
                onChanged: (value) {
                  setState(() {
                    _diabetesType = value!;
                  });
                },
                activeColor: Colors.blue[800],
              ),
            ),
            ListTile(
              title: const Text('Type 2'),
              leading: Radio<String>(
                value: 'Type 2',
                groupValue: _diabetesType,
                onChanged: (value) {
                  setState(() {
                    _diabetesType = value!;
                  });
                },
                activeColor: Colors.blue[800],
              ),
            ),
            const Divider(),
            _buildSectionHeader('Are You Insulin Dependent?', Icons.insights),
            SwitchListTile(
              title: const Text('Yes'),
              value: _isInsulinDependent,
              onChanged: (value) {
                setState(() {
                  _isInsulinDependent = value;
                });
              },
              activeColor: Colors.blue[800],
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: _completeOnboarding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save & Continue',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue[800], size: 28),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
