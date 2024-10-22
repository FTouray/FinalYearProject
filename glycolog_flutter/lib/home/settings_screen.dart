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

  @override
  void initState() {
    super.initState();
    _loadSettings(); // Load saved settings on initialization
  }

  // Load saved settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedUnit = prefs.getString('selectedUnit') ?? 'mmol/L';
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _darkModeEnabled = prefs.getBool('darkModeEnabled') ?? false;
    });
  }

  // Save settings for persistence in SharedPreferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedUnit', _selectedUnit);
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setBool('darkModeEnabled', _darkModeEnabled);

    // Trigger the dark mode change across the app
    widget.onToggleDarkMode(_darkModeEnabled); // Apply the dark mode setting across the app
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
              title: const Text('mg/dL'),
              leading: Radio<String>(
                value: 'mg/dL',
                groupValue: _selectedUnit,
                onChanged: (value) {
                  setState(() {
                    _selectedUnit = value!;
                  });
                  _saveSettings();
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
                  _saveSettings();
                },
                activeColor: Colors.blue[800],
              ),
            ),
            const Divider(),

            // Notifications Toggle
            const Text(
              'Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              title: const Text('Enable Glucose Level Notifications'),
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
                _saveSettings();
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
              title: const Text('Enable Dark Mode'),
              value: _darkModeEnabled,
              onChanged: (value) {
                setState(() {
                  _darkModeEnabled = value;
                });
                _saveSettings(); // Save dark mode setting and apply it globally
              },
              activeColor: Colors.blue[800],
            ),
          ],
        ),
      ),
    );
  }
}
