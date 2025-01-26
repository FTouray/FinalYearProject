// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'base_screen.dart'; // Import BaseScreen
import 'package:Glycolog/services/auth_service.dart'; // Import AuthServiceScreen
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  final String firstName; // Pass the first name to this page

  const HomePage({super.key, required this.firstName});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
     _checkAuthentication();
     _handleFirstLaunch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleFirstLaunch();
    }
  }

  Future<void> _checkAuthentication() async {
    AuthService authService = AuthService();
    String? token = await authService.getAccessToken();

    if (token == null) {
      // If no token, call logout function which handles redirection
      await authService.logout(context);
    } else {
      // Optionally refresh token if close to expiration
      await authService.refreshAccessToken(context);
    }
  }

  Future<void> _handleFirstLaunch() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool wasAppOpened = prefs.getBool('wasAppOpened') ?? false;

    if (!wasAppOpened) {
      // Mark the app as opened to prevent showing the pop-up again
      await prefs.setBool('wasAppOpened', true);
      _showFeelingPopup(context);
    }
  }

  void _showFeelingPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: const Text(
            "How Are You Feeling?",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FeelingOption(
                icon: Icons.sentiment_very_satisfied,
                color: Colors.green,
                label: "Good",
                onTap: () {
                  Navigator.pop(context);
                  _navigateToInsights("good");
                },
              ),
              const SizedBox(height: 15),
              _FeelingOption(
                icon: Icons.sentiment_neutral,
                color: Colors.amber,
                label: "Okay",
                onTap: () {
                  Navigator.pop(context);
                  _navigateToInsights("okay");
                },
              ),
              const SizedBox(height: 15),
              _FeelingOption(
                icon: Icons.sentiment_dissatisfied,
                color: Colors.red,
                label: "Bad",
                onTap: () {
                  Navigator.pop(context);
                  _startQuestionnaire("bad");
                  },
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  "Skip",
                  style: TextStyle(fontSize: 16, color: Colors.blue),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToInsights(String feeling) {
    Navigator.pushNamed(context, '/insights', arguments: {"feeling": feeling});
  }

  Future<void> _startQuestionnaire(String feeling) async {
    try {
      String? token = await AuthService().getAccessToken();
      print("Retrieved token: $token");

      if (token == null) {
        throw Exception("User is not authenticated.");
      }

      final response = await http.post(
        Uri.parse('http://192.168.1.11:8000/api/questionnaire/start/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'feeling': feeling}),
      );

      if (response.statusCode == 201) {
        Navigator.pushNamed(context, '/symptom-step');
      } else {
        final error = json.decode(response.body);
        print("Failed to start questionnaire: ${error['error']}");
        throw Exception(error['error'] ?? 'Failed to start questionnaire');
      }
    } catch (error) {
      print("Error in _startQuestionnaire: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting questionnaire: $error')),
      );
    }
  }



  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.pushNamed(context, '/home');
    } else if (index == 1) {
      Navigator.pushNamed(context, '/community');
    } else if (index == 2) {
      Navigator.pushNamed(context, '/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      selectedIndex: _selectedIndex,
      onItemTapped: _onItemTapped,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Welcome message
              Text(
                'Welcome, ${widget.firstName}!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              const SizedBox(height: 30),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  FeatureIcon(
                    icon: Icons.analytics,
                    label: 'Glucose Log',
                    onTap: () {
                      Navigator.pushNamed(context, '/glucose-log');
                    },
                  ),
                  FeatureIcon(
                    icon: Icons
                        .track_changes, // Icons.track_changes, Icons.show_chart, Icons.insights
                    label: 'Glycaemic Tracker',
                    onTap: () {
                      Navigator.pushNamed(context, '/glycaemic-response-main');
                    },
                  ),
                  FeatureIcon(
                    icon: Icons.settings,
                    label: 'Settings',
                    onTap: () {
                      Navigator.pushNamed(context, '/settings');
                    },
                  ),
                  FeatureIcon(
                    icon: Icons.help,
                    label: 'Help',
                    onTap: () {
                      // Navigate to help page
                    },
                  ),
                  FeatureIcon(
                    icon: Icons.info,
                    label: 'About',
                    onTap: () {},
                  ),
                  FeatureIcon(
                    icon: Icons.sentiment_satisfied,
                    label: 'How Are You Feeling?',
                    onTap: () {
                      _showFeelingPopup(context);
                    },
                  ),
                  FeatureIcon(
                    icon: Icons.insights,
                    label: 'Insights',
                    onTap: () {
                      Navigator.pushNamed(context, '/insights-graph-data');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom widget for feature icons
class FeatureIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const FeatureIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.blue[100],
      borderRadius: BorderRadius.circular(16.0),
      child: Card(
        color: Colors.white,
        elevation: 4.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: Colors.blue[800]),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeelingOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _FeelingOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
