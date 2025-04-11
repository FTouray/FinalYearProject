import 'package:Glycolog/home/base_screen.dart';
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
        content: Text('Profile Settings saved successfully!'),
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
    return BaseScaffoldScreen(
      selectedIndex: 2, 
      onItemTapped: (index) {
        final routes = ['/home', '/forum', '/settings'];
        Navigator.pushNamed(context, routes[index]);
      },
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Measurement Unit'),
            _buildRadioTile(
              title: 'mg/dL',
              value: 'mg/dL',
              groupValue: _selectedUnit,
              onChanged: (value) => setState(() => _selectedUnit = value!),
            ),
            _buildRadioTile(
              title: 'mmol/L',
              value: 'mmol/L',
              groupValue: _selectedUnit,
              onChanged: (value) => setState(() => _selectedUnit = value!),
            ),
            const Divider(),
            _buildSectionTitle('Type of Diabetes'),
            _buildRadioTile(
              title: 'Type 1',
              value: 'Type 1',
              groupValue: _diabetesType,
              icon: Icons.bloodtype,
              iconColor: Colors.red,
              onChanged: (value) => setState(() => _diabetesType = value!),
            ),
            _buildRadioTile(
              title: 'Type 2',
              value: 'Type 2',
              groupValue: _diabetesType,
              icon: Icons.local_hospital,
              iconColor: Colors.green,
              onChanged: (value) => setState(() => _diabetesType = value!),
            ),
            const Divider(),
            _buildSectionTitle('Insulin Dependency'),
            SwitchListTile(
              secondary: const Icon(Icons.medication, color: Colors.orange),
              title: const Text('Yes'),
              value: _isInsulinDependent,
              onChanged: (value) => setState(() => _isInsulinDependent = value),
              activeColor: Colors.blue[800],
            ),
            const Divider(),
            _buildSectionTitle('Target Glucose Range'),
            _buildTargetRangeField(
                _targetMinController, 'Minimum ($_selectedUnit)'),
            const SizedBox(height: 16),
            _buildTargetRangeField(
                _targetMaxController, 'Maximum ($_selectedUnit)'),
            const Divider(),
            _buildSectionTitle('Notifications'),
            SwitchListTile(
              secondary: const Icon(Icons.notifications, color: Colors.blue),
              title: const Text('Enable Glucose Level Notifications'),
              value: _notificationsEnabled,
              onChanged: (value) =>
                  setState(() => _notificationsEnabled = value),
              activeColor: Colors.blue[800],
            ),
            const Divider(),
            _buildSectionTitle('Theme Settings'),
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode, color: Colors.black),
              title: const Text('Enable Dark Mode'),
              value: _darkModeEnabled,
              onChanged: (value) => setState(() => _darkModeEnabled = value),
              activeColor: Colors.blue[800],
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  if (_validateTargetRange()) _saveSettings();
                },
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
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

Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String value,
    required String? groupValue,
    required void Function(String?) onChanged,
    IconData? icon,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon ?? Icons.radio_button_checked,
          color: iconColor ?? Colors.blue[800]),
      title: Text(title),
      trailing: Radio<String>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        activeColor: Colors.blue[800],
      ),
    );
  }

  Widget _buildTargetRangeField(
      TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        errorText: _targetRangeError,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    );
  }

}
