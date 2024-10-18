import 'package:flutter/material.dart';

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
    required this.mealContext,  // Initialize meal context
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Glucose Log'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Glucose Level: $glucoseLevel $measurementUnit',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            Text(
              'Date: ${selectedDate.toLocal()}'.split(' ')[0],
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              'Time: ${selectedTime.format(context)}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),

            // Display meal context
            Text(
              'Meal Context: ${mealContext == 'fasting' ? 'Fasting' : mealContext == 'pre_meal' ? 'Pre-Meal' : 'Post-Meal'}',
              style: const TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 20),
            const Text(
              'Please confirm if you want to save this entry.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Go back to the previous screen to edit
                    Navigator.pop(context);
                  },
                  child: const Text('Edit'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Save the log entry
                    Navigator.pop(context, true); // Indicate confirmation
                  },
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
