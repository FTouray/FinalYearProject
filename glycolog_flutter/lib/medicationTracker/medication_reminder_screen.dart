import 'package:flutter/material.dart';

class MedicationReminderScreen extends StatelessWidget {
  final Map<String, dynamic> medication;

  const MedicationReminderScreen({super.key, required this.medication});

  @override
  Widget build(BuildContext context) {
    TimeOfDay? selectedTime;

    return Scaffold(
      appBar: AppBar(title: const Text("Set Medication Reminder")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("Setting reminder for: ${medication['name']}"),
            ListTile(
              title: const Text("Reminder Time"),
              subtitle: Text(selectedTime != null
                  ? "${selectedTime.hour}:${selectedTime.minute}"
                  : "Not set"),
              trailing: IconButton(
                icon: const Icon(Icons.access_time),
                onPressed: () async {
                  TimeOfDay? pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (pickedTime != null) {
                    selectedTime = pickedTime;
                  }
                },
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Set Reminder"),
            ),
          ],
        ),
      ),
    );
  }
}
