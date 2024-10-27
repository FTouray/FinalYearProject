import 'package:flutter/material.dart';
import 'package:Glycolog/services/auth_service.dart';

class BaseScreen extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final Widget body;
  final AuthService authService = AuthService(); // Initialize AuthService here

  BaseScreen({
    Key? key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.body,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/logos/glycolog_logo.png',
            height: 40), // Logo in the middle
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu), // Hamburger menu icon
            onPressed: () {
              // Use the context of the Scaffold to open the drawer
              Scaffold.of(context)
                  .openDrawer(); // Correct context for opening the drawer
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout), // Logout icon
            onPressed: () async {
              await _logout(context); // Call logout function
            },
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
              child: const Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context); // Close the drawer first
                Navigator.pushNamed(context, '/home');
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Glucose Log'),
              onTap: () {
                Navigator.pop(context); // Close the drawer first
                Navigator.pushNamed(context, '/glucose-log');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await _logout(context); // Call logout function
              },
            ),
          ],
        ),
      ),
      body: body, // This will hold the main content of the page
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.blue[800],
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.blue[200],
        currentIndex: selectedIndex,
        onTap: (index) {
          onItemTapped(index);
          if (index == 0) {
            // If the first item (Home) is tapped, navigate to Home
            Navigator.pushNamed(context, '/home');
          }
        },
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // Logout function using AuthService
  Future<void> _logout(BuildContext context) async {
    await authService.logout(context); // AuthService handles navigation
  }
}