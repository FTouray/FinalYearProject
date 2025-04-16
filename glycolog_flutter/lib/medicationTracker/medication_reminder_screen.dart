import 'package:glycolog/services/auth_service.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MedicationReminderScreen extends StatefulWidget {
  final Map<String, dynamic> medication;

  const MedicationReminderScreen({super.key, required this.medication});

  @override
  State<MedicationReminderScreen> createState() => _MedicationReminderScreenState();
}

class _MedicationReminderScreenState extends State<MedicationReminderScreen> {
  TimeOfDay selectedTime = TimeOfDay.now();
  String selectedDay = "Monday";
  String frequencyType = "Weekly";
  int repeatInterval = 1;
  int repeatDuration = 4;

  final DeviceCalendarPlugin _calendarPlugin = DeviceCalendarPlugin();
  String? _calendarId;

  final List<String> daysOfWeek = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday"
  ];

  final List<String> frequencyTypes = ["Daily", "Weekly", "Monthly"];

  @override
  void initState() {
    super.initState();
    _requestCalendarPermissions();
  }

  Future<void> _requestCalendarPermissions() async {
    final result = await _calendarPlugin.requestPermissions();
    if (result.isSuccess && result.data == true) {
      final calendarsResult = await _calendarPlugin.retrieveCalendars();
      _calendarId = calendarsResult.data!.first.id;
    }
  }

  Future<void> submitReminderToServer() async {
    final dayInt = _dayStringToInt(selectedDay);
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
        "repeat_weeks": repeatDuration
      }),
    );

    if (response.statusCode == 201) {
      await _addCalendarEvents();
      
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Reminder Added"),
          content: const Text("Your medication reminders have been added to your calendar."),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
       ).then((_) {
        if (mounted) Navigator.pop(context); // 👈 Also check again here
      });
    } else {
      if (!mounted) return;
      print("Failed to set reminder: ${response.body}");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to set reminder")),
      );
    }
  }

  Future<void> _addCalendarEvents() async {
    if (_calendarId == null) return;

    final now = DateTime.now();
    final dayOffset = (_dayStringToInt(selectedDay) - now.weekday + 7) % 7;

    DateTime startDate = DateTime(now.year, now.month, now.day)
        .add(Duration(days: dayOffset))
        .copyWith(hour: selectedTime.hour, minute: selectedTime.minute);

    final endDate = startDate.add(const Duration(minutes: 5));

    RecurrenceFrequency frequency;
    switch (frequencyType) {
      case "Daily":
        frequency = RecurrenceFrequency.Daily;
        break;
      case "Monthly":
        frequency = RecurrenceFrequency.Monthly;
        break;
      case "Weekly":
      default:
        frequency = RecurrenceFrequency.Weekly;
    }

    final event = Event(
      _calendarId,
      title: 'Take ${widget.medication['name']}',
      description: 'Medication reminder from Glycolog',
      start: TZDateTime.from(startDate, local),
      end: TZDateTime.from(endDate, local),
      recurrenceRule: RecurrenceRule(
        frequency,
        interval: repeatInterval,
        endDate: TZDateTime.from(
          frequency == RecurrenceFrequency.Daily
              ? startDate.add(Duration(days: repeatInterval * repeatDuration))
              : frequency == RecurrenceFrequency.Weekly
                  ? startDate.add(Duration(days: repeatInterval * 7 * repeatDuration))
                  : startDate.add(Duration(days: 30 * repeatInterval * repeatDuration)),
          local,
        ),
      ),
    );

    final result = await _calendarPlugin.createOrUpdateEvent(event);

    if (result?.isSuccess == true && result?.data != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('eventId_med${widget.medication["id"]}', result!.data!);
    }
  }

  int _dayStringToInt(String day) {
    switch (day) {
      case "Monday": return 1;
      case "Tuesday": return 2;
      case "Wednesday": return 3;
      case "Thursday": return 4;
      case "Friday": return 5;
      case "Saturday": return 6;
      case "Sunday": return 7;
      default: return 1;
    }
  }

  String getUnitLabel(String type) {
    switch (type) {
      case "Daily":
        return "days";
      case "Weekly":
        return "weeks";
      case "Monthly":
        return "months";
      default:
        return "periods";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Set Reminder for ${widget.medication['name']}")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<String>(
              value: selectedDay,
              items: daysOfWeek
                  .map((day) => DropdownMenuItem(value: day, child: Text(day)))
                  .toList(),
              onChanged: (value) => setState(() => selectedDay = value!),
            ),
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
            DropdownButton<String>(
              value: frequencyType,
              items: frequencyTypes
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) => setState(() => frequencyType = value!),
            ),
            Row(
              children: [
                const Text("Repeat every: "),
                const SizedBox(width: 10),
                DropdownButton<int>(
                  value: repeatInterval,
                  items: List.generate(30, (index) => index + 1)
                      .map((val) => DropdownMenuItem(value: val, child: Text("$val")))
                      .toList(),
                  onChanged: (value) => setState(() => repeatInterval = value!),
                ),
                const SizedBox(width: 10),
                Text(frequencyType.toLowerCase()),
              ],
            ),
           Row(
              children: [
                const Text("Repeat for "),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: repeatDuration,
                  items: [1, 2, 3, 4, 6, 8, 12]
                      .map((val) => DropdownMenuItem(
                            value: val,
                            child: Text("$val ${getUnitLabel(frequencyType)}"),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => repeatDuration = val!),
                ),
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
