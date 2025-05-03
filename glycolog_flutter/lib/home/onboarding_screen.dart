// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  OnboardingScreenState createState() => OnboardingScreenState();
}

class OnboardingScreenState extends State<OnboardingScreen> {
  String _selectedUnit = 'mg/dL'; // Default unit
  String _diabetesType = 'Type 1'; // Default diabetes type
  bool _isInsulinDependent = false; // Default insulin dependency
  final TextEditingController _targetMinController = TextEditingController();
  final TextEditingController _targetMaxController = TextEditingController();
  String? _targetRangeError;

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedUnit', _selectedUnit);
    await prefs.setString('diabetesType', _diabetesType);
    await prefs.setBool('isInsulinDependent', _isInsulinDependent);

    // Save target range in consistent unit (mg/dL)
    double targetMin = double.parse(_targetMinController.text);
    double targetMax = double.parse(_targetMaxController.text);

    if (_selectedUnit == 'mmol/L') {
      targetMin = targetMin * 18; // Convert mmol/L to mg/dL
      targetMax = targetMax * 18;
    }

    await prefs.setDouble('targetMin', targetMin);
    await prefs.setDouble('targetMax', targetMax);
    await prefs.setBool('onboardingCompleted', true);

      // Debug: Log or print to ensure flag is set
    print('Onboarding Completed: true');
    // Mark onboarding as complete
    await prefs.setBool('onboardingCompleted', true);

    if (!mounted) return;

    // Navigate to HomePage after saving preferences
    Navigator.pushReplacementNamed(context, '/home');
  }

  bool _validateTargetRange() {
    try {
      double min = double.parse(_targetMinController.text);
      double max = double.parse(_targetMaxController.text);

      // Define valid ranges based on the selected unit
      double minValid = (_selectedUnit == 'mg/dL') ? 10 : 0.55;
      double maxValid = (_selectedUnit == 'mg/dL') ? 600 : 33.3;

      if (min < minValid || max > maxValid) {
        setState(() {
          _targetRangeError =
              'Values must be between $minValid and $maxValid $_selectedUnit.';
        });
        return false;
      }

      if (min >= max) {
        setState(() {
          _targetRangeError =
              'Minimum value should be less than maximum value.';
        });
        return false;
      }

      setState(() {
        _targetRangeError = null; // Clear error if validation passes
      });
      return true;
    } catch (e) {
      setState(() {
        _targetRangeError = 'Please enter valid numeric values.';
      });
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Your Preferences'),
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
            const Divider(),
            _buildSectionHeader(
                'Set Your Target Glucose Range', Icons.show_chart),
            TextField(
              controller: _targetMinController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Minimum ($_selectedUnit)',
                errorText: _targetRangeError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _targetMaxController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Maximum ($_selectedUnit)',
                errorText: _targetRangeError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  if (_validateTargetRange()) {
                    _completeOnboarding();
                  }
                },
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
