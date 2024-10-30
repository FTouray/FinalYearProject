import 'package:flutter/material.dart';
import 'base_screen.dart'; // Import BaseScreen
import 'package:Glycolog/services/auth_service.dart'; // Import AuthServiceScreen

class HomePage extends StatefulWidget {
  final String firstName; // Pass the first name to this page

  const HomePage({super.key, required this.firstName});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; // Index for bottom navigation

  // Navigation for Bottom Bar
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Handle navigation based on the selected index
    if (index == 0) {
      // Home
      Navigator.pushNamed(context, '/home');
    } else if (index == 1) {
      // Community Forum
      Navigator.pushNamed(context, '/community');
    } else if (index == 2) {
      // Profile
      Navigator.pushNamed(context, '/profile');
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

  @override
  void initState() {
    super.initState();
    _checkAuthentication(); // Check if the user is authenticated when the page initialises
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
              // Feature Icons
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2, // Two icons per row
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
                    onTap: () {
                      // Navigate to about page
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
