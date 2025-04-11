import 'package:Glycolog/services/auth_service.dart';
import 'package:Glycolog/services/reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MedicationReminderScreen extends StatefulWidget {
  final Map<String, dynamic> medication;

  const MedicationReminderScreen({super.key, required this.medication});

  @override
  State<MedicationReminderScreen> createState() =>
      _MedicationReminderScreenState();
}

class _MedicationReminderScreenState extends State<MedicationReminderScreen> {
  TimeOfDay selectedTime = TimeOfDay.now();
  String selectedDay = "Monday";
  int repeatWeeks = 4;

  final List<String> daysOfWeek = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday"
  ];

  Future<void> submitReminderToServer() async {
    // Convert day string to integer: Monday=1, Tuesday=2, ...
    final dayInt = _dayStringToInt(selectedDay);

    // Suppose you store your token in some AuthService
    final token = await AuthService().getAccessToken();
    if (token == null) return;

    final apiUrl = dotenv.env['API_URL'];
    final url = Uri.parse('$apiUrl/reminders/set/');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        "medication_id": widget.medication["id"],
        "day_of_week": dayInt,
        "hour": selectedTime.hour,
        "minute": selectedTime.minute,
        "repeat_weeks": repeatWeeks
      }),
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reminder set on server successfully!")),
      );
      // await ReminderService.syncRemindersWithLocalNotifications();
      // Navigator.pop(context, true);
      Navigator.pop(context);
    } else {
      print("Failed to set reminder: ${response.body}");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to set reminder")),
      );
    }
  }

  int _dayStringToInt(String day) {
    switch (day) {
      case "Monday":
        return 1;
      case "Tuesday":
        return 2;
      case "Wednesday":
        return 3;
      case "Thursday":
        return 4;
      case "Friday":
        return 5;
      case "Saturday":
        return 6;
      case "Sunday":
        return 7;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text("Set Reminder for ${widget.medication['name']}")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Day of week
            DropdownButton<String>(
              value: selectedDay,
              items: daysOfWeek
                  .map((day) => DropdownMenuItem(
                        value: day,
                        child: Text(day),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedDay = value;
                  });
                }
              },
            ),
            // Time
            ListTile(
              title: const Text("Reminder Time"),
              subtitle: Text(selectedTime.format(context)),
              trailing: IconButton(
                icon: const Icon(Icons.access_time),
                onPressed: () async {
                  TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (picked != null) {
                    setState(() => selectedTime = picked);
                  }
                },
              ),
            ),
            // Repeat Weeks
            Row(
              children: [
                const Text("Repeat for (weeks):"),
                const SizedBox(width: 10),
                DropdownButton<int>(
                  value: repeatWeeks,
                  items: [1, 2, 3, 4, 5, 6, 8, 12].map((val) {
                    return DropdownMenuItem<int>(
                      value: val,
                      child: Text("$val"),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => repeatWeeks = value);
                    }
                  },
                )
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: submitReminderToServer,
              child: const Text("Set Reminder"),
            )
          ],
        ),
      ),
    );
  }
}
