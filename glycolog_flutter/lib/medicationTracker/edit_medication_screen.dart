import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditMedicationScreen extends StatefulWidget {
  final Map<String, dynamic> medication;

  const EditMedicationScreen({super.key, required this.medication});

  @override
  State<EditMedicationScreen> createState() => _EditMedicationScreenState();
}

class _EditMedicationScreenState extends State<EditMedicationScreen> {
  late TextEditingController nameController;
  late TextEditingController dosageController;
  late TextEditingController frequencyController;
  DateTime? lastTaken;

  final String? apiUrl = dotenv.env['API_URL'];
  final DeviceCalendarPlugin _calendarPlugin = DeviceCalendarPlugin();

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.medication['name']);
    dosageController = TextEditingController(text: widget.medication['dosage']);
    frequencyController =
        TextEditingController(text: widget.medication['frequency']);
    lastTaken = widget.medication['last_taken'] != null
        ? DateTime.tryParse(widget.medication['last_taken'])
        : null;
  }

  Future<void> saveChanges() async {
    final token = await AuthService().getAccessToken();
    if (token == null) return;

    final response = await http.put(
      Uri.parse('$apiUrl/medications/update/${widget.medication['id']}/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "name": nameController.text,
        "dosage": dosageController.text,
        "frequency": frequencyController.text,
        "last_taken": lastTaken?.toIso8601String(),
      }),
    );

    if (response.statusCode == 200) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Failed to update")));
    }
  }

  Future<void> deleteMedication() async {
    final token = await AuthService().getAccessToken();
    if (token == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final eventKey = 'eventId_med${widget.medication["id"]}';
      final eventId = prefs.getString(eventKey);

      if (eventId != null) {
        final calendars = await _calendarPlugin.retrieveCalendars();
        final calendarId = calendars.data?.first.id;

        if (calendarId != null) {
          await _calendarPlugin.deleteEvent(calendarId, eventId);
          await prefs.remove(eventKey);
        }
      }
    } catch (e) {
      debugPrint("Error removing calendar event: $e");
    }

    final response = await http.delete(
      Uri.parse('$apiUrl/medications/delete/${widget.medication['id']}/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Delete failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Medication")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Medication Name"),
            ),
            TextField(
              controller: dosageController,
              decoration: const InputDecoration(labelText: "Dosage"),
            ),
            TextField(
              controller: frequencyController,
              decoration: const InputDecoration(labelText: "Frequency"),
            ),
            ListTile(
              title: const Text("Last Taken"),
              subtitle: Text(
                lastTaken != null
                    ? lastTaken!.toLocal().toString().split(' ')[0]
                    : "Not set",
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: lastTaken ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => lastTaken = picked);
                  }
                },
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: saveChanges, child: const Text("Save")),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: deleteMedication,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child:
                  const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
