import 'package:flutter/material.dart';

class LogDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> logDetails; // Log details passed as arguments

  const LogDetailsScreen({super.key, required this.logDetails});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Log Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Glucose Level: ${logDetails['glucoseLevel']}',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text('Date: ${logDetails['timestamp']}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            Text('Meal Context: ${logDetails['mealContext'] ?? "Not specified"}', style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
