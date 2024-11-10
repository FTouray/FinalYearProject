import 'package:flutter/material.dart';
import 'package:Glycolog/utils.dart';

class GlucoseLogConfirmationScreen extends StatelessWidget {
  final double glucoseLevel;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final String measurementUnit;
  final String mealContext;

  const GlucoseLogConfirmationScreen({
    Key? key,
    required this.glucoseLevel,
    required this.selectedDate,
    required this.selectedTime,
    required this.measurementUnit,
    required this.mealContext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Confirm Glucose Log',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Glucose Level Display
            _buildInfoTile(
              label: 'Glucose Level',
              value: '$glucoseLevel $measurementUnit',
              icon: Icons.opacity,
              color: Colors.blue[600],
            ),

            const SizedBox(height: 20),

            // Date Display
            _buildInfoTile(
              label: 'Date',
              value: formatDate(selectedDate),
              icon: Icons.calendar_today,
              color: Colors.green[600],
            ),

            const SizedBox(height: 20),

            // Time Display
            _buildInfoTile(
              label: 'Time',
              value: formatTime(selectedTime),
              icon: Icons.access_time,
              color: Colors.orange[600],
            ),

            const SizedBox(height: 20),

            // Meal Context Display
            _buildInfoTile(
              label: 'Meal Context',
              value: mealContext == 'fasting'
                  ? 'Fasting'
                  : mealContext == 'pre_meal'
                      ? 'Pre-Meal'
                      : 'Post-Meal',
              icon: Icons.restaurant,
              color: Colors.red[600],
            ),

            const SizedBox(height: 40),

            // Confirmation Message
            const Text(
              'Please confirm if you want to save this entry.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 30),

            // Buttons (Edit and Confirm)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Go back to edit
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[400], // Edit button color
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, true); // Confirm the entry
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800], // Confirm button color
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for displaying a tile of information (e.g., glucose level, date, time)
  Widget _buildInfoTile({
    required String label,
    required String value,
    required IconData icon,
    required Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            child: Icon(
              icon,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
