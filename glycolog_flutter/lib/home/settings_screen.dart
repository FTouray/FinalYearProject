import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool) onToggleDarkMode; // Callback to toggle dark mode

  const SettingsScreen({super.key, required this.onToggleDarkMode});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedUnit = 'mg/dL'; // Default unit for glucose measurement
  bool _notificationsEnabled = true; // Notifications on by default
  bool _darkModeEnabled = false; // Dark mode off by default
  String _diabetesType = 'Type 1'; // Default diabetes type
  bool _isInsulinDependent = false; // Default insulin dependency
  final TextEditingController _targetMinController = TextEditingController();
  final TextEditingController _targetMaxController = TextEditingController();
  String? _targetRangeError; // Validation error for target range

  @override
  void initState() {
    super.initState();
    _loadPreferences(); // Load saved settings
  }

  // Load saved settings from SharedPreferences
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedUnit = prefs.getString('selectedUnit') ?? 'mg/dL';
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _darkModeEnabled = prefs.getBool('darkModeEnabled') ?? false;
      _diabetesType = prefs.getString('diabetesType') ?? 'Type 1';
      _isInsulinDependent = prefs.getBool('isInsulinDependent') ?? false;
    // Load target range and convert to user-selected unit if necessary
      double? targetMin = prefs.getDouble('targetMin');
      double? targetMax = prefs.getDouble('targetMax');
      if (targetMin != null && targetMax != null) {
        if (_selectedUnit == 'mmol/L') {
          targetMin /= 18; // Convert mg/dL to mmol/L
          targetMax /= 18;
        }
        _targetMinController.text = targetMin.toStringAsFixed(1);
        _targetMaxController.text = targetMax.toStringAsFixed(1);
      }
    });
  }

  // Save settings for persistence in SharedPreferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedUnit', _selectedUnit);
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setBool('darkModeEnabled', _darkModeEnabled);
    await prefs.setString('diabetesType', _diabetesType);
    await prefs.setBool('isInsulinDependent', _isInsulinDependent);

    // Save target range in mg/dL for consistency
    double targetMin = double.parse(_targetMinController.text);
    double targetMax = double.parse(_targetMaxController.text);
    if (_selectedUnit == 'mmol/L') {
      targetMin *= 18; // Convert mmol/L to mg/dL
      targetMax *= 18;
    }
    await prefs.setDouble('targetMin', targetMin);
    await prefs.setDouble('targetMax', targetMax);

    // Trigger the dark mode change across the app
    widget.onToggleDarkMode(_darkModeEnabled);

    // Show confirmation message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

// Validate the target range
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
          _targetRangeError = 'Minimum must be less than maximum.';
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
        title: const Text('Settings'),
        backgroundColor: Colors.blue[800],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Measurement Unit',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: Icon(Icons.scale, color: Colors.blue[800]),
              title: const Text('mg/dL'),
              trailing: Radio<String>(
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
              leading: Icon(Icons.scale_outlined, color: Colors.blue[800]),
              title: const Text('mmol/L'),
              trailing: Radio<String>(
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

            // Type of Diabetes
            const Text(
              'Type of Diabetes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: Icon(Icons.bloodtype, color: Colors.red),
              title: const Text('Type 1'),
              trailing: Radio<String>(
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
              leading: Icon(Icons.local_hospital, color: Colors.green),
              title: const Text('Type 2'),
              trailing: Radio<String>(
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

            // Insulin Dependency
            const Text(
              'Insulin Dependency',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              secondary: Icon(Icons.medication, color: Colors.orange),
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

            // Target Range
            const Text(
              'Target Glucose Range',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
            const Divider(),

            // Notifications Toggle
            const Text(
              'Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              secondary: Icon(Icons.notifications, color: Colors.blue),
              title: const Text('Enable Glucose Level Notifications'),
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
              activeColor: Colors.blue[800],
            ),
            const Divider(),

            // Dark Mode Toggle
            const Text(
              'Theme Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              secondary: Icon(Icons.dark_mode, color: Colors.black),
              title: const Text('Enable Dark Mode'),
              value: _darkModeEnabled,
              onChanged: (value) {
                setState(() {
                  _darkModeEnabled = value;
                });
              },
              activeColor: Colors.blue[800],
            ),
            const SizedBox(height: 30),

            // Save All Settings Button
            Center(
              child: ElevatedButton(
                onPressed: () {
                  if (_validateTargetRange()) {
                    _saveSettings();
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 15,
                  ),
                  backgroundColor: Colors.blue[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: const Text(
                  'Save All Settings',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
