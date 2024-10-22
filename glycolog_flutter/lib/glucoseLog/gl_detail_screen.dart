import 'package:flutter/material.dart';

class LogDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> logDetails;

  const LogDetailsScreen({super.key, required this.logDetails});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Details'),
        backgroundColor: Colors.blue[800], // Consistent blue theme for the app bar
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Glucose Level Card
            _buildInfoCard(
              icon: Icons.show_chart,
              title: 'Glucose Level',
              content: '${logDetails['glucose_level']}',
              context: context,
            ),
            const SizedBox(height: 20),

            // Date Card
            _buildInfoCard(
              icon: Icons.calendar_today,
              title: 'Date',
              content: '${logDetails['timestamp']}',
              context: context,
            ),
            const SizedBox(height: 20),

            // Meal Context Card
            _buildInfoCard(
              icon: Icons.restaurant_menu,
              title: 'Meal Context',
              content: '${logDetails['meal_context'] ?? "Not specified"}',
              context: context,
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to create consistent info cards for each log detail
  Widget _buildInfoCard({required IconData icon, required String title, required String content, required BuildContext context}) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.blue[800]), // Icon representing the content type
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: const TextStyle(fontSize: 18, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
