import 'package:flutter/material.dart';

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
      Navigator.pushReplacementNamed(context, '/home');
    } else if (index == 1) {
      // Glucose Log
      Navigator.pushNamed(context, '/glucose-log');
    } else if (index == 2) {
      // Profile
      Navigator.pushNamed(context, '/profile');
    }
  }

  // Logout Function
  void _logout() {
    // Handle logout logic here
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[50], // Matching background color
      appBar: AppBar(
        title: Image.asset(
          'assets/logos/glycolog_logo.png',
          height: 40,
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[800], // Matching app bar color
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue[800],
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home, color: Colors.blue[800]),
              title: Text('Home'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
            ),
            ListTile(
              leading: Icon(Icons.analytics, color: Colors.blue[800]),
              title: Text('Glucose Log'),
              onTap: () {
                Navigator.pushNamed(context, '/glucose-log');
              },
            ),
            // Future features can be added here
            ListTile(
              leading: Icon(Icons.logout, color: Colors.blue[800]),
              title: Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              SizedBox(height: 20),
              // Welcome message
              Text(
                'Welcome, ${widget.firstName}!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              SizedBox(height: 30),
              // Feature Icons
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2, // Two icons per row
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  FeatureIcon(
                    icon: Icons.analytics,
                    label: 'Glucose Log',
                    onTap: () {
                      Navigator.pushNamed(context, '/glucose-log');
                    },
                  ),
                  // Placeholder for future features
                  FeatureIcon(
                    icon: Icons.settings,
                    label: 'Settings',
                    onTap: () {
                      // Navigate to settings page
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
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.blue[800],
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.blue[200],
        currentIndex: _selectedIndex, // Highlight the current selected tab
        onTap: _onItemTapped, // Handle tab navigation
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Log',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Profile',
          ),
        ],
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
              SizedBox(height: 10),
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
