import 'package:glycolog/home/base_screen.dart';
import 'package:glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool) onToggleDarkMode; // Callback to toggle dark mode

  const SettingsScreen({super.key, required this.onToggleDarkMode});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _selectedUnit = 'mg/dL'; // Default unit for glucose measurement
  bool _notificationsEnabled = true; // Notifications on by default
  bool _darkModeEnabled = false; // Dark mode off by default
  String _diabetesType = 'Type 1'; // Default diabetes type
  bool _isInsulinDependent = false; // Default insulin dependency
  final TextEditingController _targetMinController = TextEditingController();
  final TextEditingController _targetMaxController = TextEditingController();
  String? _targetRangeError; // Validation error for target range
  final String? apiUrl = dotenv.env['API_URL'];
  bool _profileFetched = false;
  bool _isEditingProfile = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_profileFetched) {
      fetchUserProfile(); // this ensures it's only called once
      _profileFetched = true;
    }
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

  Future<void> fetchUserProfile() async {
    final token = await AuthService().getAccessToken();
    print("🔑 Access Token: $token");

    if (token == null) {
      print("❌ No token found.");
      return;
    }

    final res = await http.get(
      Uri.parse('$apiUrl/profile/details'),
      headers: {'Authorization': 'Bearer $token'},
    );


    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      print("✅ Profile data received: $data");

      setState(() {
        _firstNameController.text = data['first_name'] ?? '';
        _lastNameController.text = data['last_name'] ?? '';
        _emailController.text = data['email'] ?? '';
        _phoneController.text = data['phone_number'] ?? '';
      });
    } else {
      print("⚠️ Failed to load profile: ${res.statusCode}");
      print("🧾 Body: ${res.body}");
    }
  }



  // Save settings for persistence in SharedPreferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await AuthService().getAccessToken();
    final apiUrl = dotenv.env['API_URL'];

    await prefs.setString('selectedUnit', _selectedUnit);
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setBool('darkModeEnabled', _darkModeEnabled);
    await prefs.setString('diabetesType', _diabetesType);
    await prefs.setBool('isInsulinDependent', _isInsulinDependent);

    await prefs.setString('first_name', _firstNameController.text);
    await prefs.setString('last_name', _lastNameController.text);
    await prefs.setString('email', _emailController.text);
    await prefs.setString('phone_number', _phoneController.text);

    // Save target range in mg/dL for consistency
    double targetMin = double.parse(_targetMinController.text);
    double targetMax = double.parse(_targetMaxController.text);
    if (_selectedUnit == 'mmol/L') {
      targetMin *= 18;
      targetMax *= 18;
    }
    await prefs.setDouble('targetMin', targetMin);
    await prefs.setDouble('targetMax', targetMax);

    // Send to backend
    if (token != null) {
      final res = await http.patch(
        Uri.parse('$apiUrl/update/profile/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "first_name": _firstNameController.text,
          "last_name": _lastNameController.text,
          "email": _emailController.text,
          "phone_number": _phoneController.text,
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        print("✅ Profile updated on server");
      } else {
        print("⚠️ Failed to update profile on server: ${res.statusCode}");
      }
    }

    widget.onToggleDarkMode(_darkModeEnabled);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile settings saved successfully!'),
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
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_circle, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text("Your Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            _isEditingProfile ? Icons.close : Icons.edit,
                            color: Colors.blue,
                          ),
                          onPressed: () {
                            setState(() {
                              _isEditingProfile = !_isEditingProfile;
                            });
                          },
                          tooltip: _isEditingProfile ? "Cancel Editing" : "Edit Profile",
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildProfileField(_firstNameController, 'First Name', icon: Icons.badge, enabled: _isEditingProfile),
                    _buildProfileField(_lastNameController, 'Last Name', icon: Icons.person, enabled: _isEditingProfile),
                    _buildProfileField(_emailController, 'Email', icon: Icons.email, inputType: TextInputType.emailAddress, enabled: _isEditingProfile),
                    _buildProfileField(_phoneController, 'Phone Number', icon: Icons.phone, inputType: TextInputType.phone, enabled: _isEditingProfile),
                  ],
                ),
              ),
            ),

            const Divider(),
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
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_validateTargetRange()) _saveSettings();
                },
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text(
                  'Save All Settings',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  backgroundColor: Colors.blue[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

Widget _buildProfileField(TextEditingController controller, String label,
      {IconData? icon,
      TextInputType inputType = TextInputType.text,
      bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: inputType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon ?? Icons.person_outline),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
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
