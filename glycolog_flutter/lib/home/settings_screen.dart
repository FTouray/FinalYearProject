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
                onPressed: _saveSettings,
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
