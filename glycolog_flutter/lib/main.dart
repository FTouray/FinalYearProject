import 'package:flutter/material.dart';
import 'login_screen.dart'; // Import the LoginScreen
import 'homepage_screen.dart'; // Import the HomePage
import 'register_screen.dart'; // Import the RegisterScreen

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glycolog App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/login', // Set initial route to login page
      routes: {
        '/login': (context) => const LoginScreen(), // Navigate to the login screen
        '/home': (context) {
          // Extract arguments (first name) passed during navigation
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is String) {
            return HomePage(firstName: args); // Pass first name to the HomePage
          } else {
            // Handle the error case here, maybe return a default or error page
            return HomePage(firstName: 'User'); // Default name if args is not a String
          }
        },
        '/register': (context) => const RegisterScreen(), // Navigate to RegisterScreen
      },
    );
  }
}
