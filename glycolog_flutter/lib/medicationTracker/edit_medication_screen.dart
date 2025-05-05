import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:glycolog/services/auth_service.dart';
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

    if (!mounted) return;

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

    if (!mounted) return;

    if (response.statusCode == 200) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Delete failed")));
    }
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Medication")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(Icons.edit, "Medication Info"),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: nameController,
                      decoration:
                          const InputDecoration(labelText: "Medication Name"),
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
                      contentPadding: EdgeInsets.zero,
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: saveChanges,
                icon: const Icon(Icons.save),
                label: const Text("Save Changes"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton.icon(
                onPressed: deleteMedication,
                icon: const Icon(Icons.delete_forever),
                label: const Text("Delete Medication"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
