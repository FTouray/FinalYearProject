import 'package:glycolog/services/auth_service.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;


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
  String frequencyType = "Weekly";
  int repeatInterval = 1;
  int repeatDuration = 4;

  final DeviceCalendarPlugin _calendarPlugin = DeviceCalendarPlugin();
  List<Calendar> _availableCalendars = [];

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
      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        setState(() {
          _availableCalendars = calendarsResult.data!
              .where((cal) => cal.isReadOnly != true)
              .toList();
        });
      }
    } else {
      print("🚫 Calendar permission not granted.");
    }
  }

  Future<void> submitReminderToServer() async {
    if (_availableCalendars.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No writable calendars found")),
      );
      return;
    }

    final token = await AuthService().getAccessToken();
    if (token == null) return;

    final dayInt = daysOfWeek.indexOf(selectedDay) + 1;
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
        "frequency_type": frequencyType.toLowerCase(),
        "interval": repeatInterval,
        "duration": repeatDuration,
        "hour": selectedTime.hour,
        "minute": selectedTime.minute,
        if (frequencyType == "Weekly") "day_of_week": dayInt,
        if (frequencyType == "Monthly") "day_of_month": DateTime.now().day
      }),
    );

    if (response.statusCode == 201) {
      await _addCalendarEvents();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text("Reminder Added"),
          content: Text(
              "Your medication reminders have been added to your calendar."),
        ),
      ).then((_) {
        if (mounted) Navigator.pop(context);
      });
    } else {
      print("❌ Failed to set reminder: ${response.body}");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to set reminder")),
      );
    }
  }

  Future<void> _addCalendarEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final eventKeyPrefix = 'eventId_med${widget.medication["id"]}_';

    // Initialise timezone database
    tzdata.initializeTimeZones();
    final String timeZoneName = DateTime.now().timeZoneName;
    final tz.Location local = tz.getLocation(timeZoneName);

    final now = DateTime.now();
    final dayOffset = (daysOfWeek.indexOf(selectedDay) - now.weekday + 7) % 7;
    final scheduledDate = now.add(Duration(days: dayOffset));
    final startDate = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
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

    final totalDays = frequency == RecurrenceFrequency.Weekly
        ? repeatInterval * 7 * repeatDuration
        : frequency == RecurrenceFrequency.Daily
            ? repeatInterval * repeatDuration
            : 30 * repeatInterval * repeatDuration;
    final recurrenceEndDate = startDate.add(Duration(days: totalDays));

    for (final calendar in _availableCalendars) {
      final eventKey = '$eventKeyPrefix${calendar.id}';
      final oldEventId = prefs.getString(eventKey);

      if (oldEventId != null) {
        final deleteResult =
            await _calendarPlugin.deleteEvent(calendar.id!, oldEventId);
        if (deleteResult.isSuccess && deleteResult.data == true) {
          await prefs.remove(eventKey);
        }
      }

      final event = Event(
        calendar.id,
        title: 'Take ${widget.medication['name']}',
        start: tz.TZDateTime.from(startDate, local),
        end: tz.TZDateTime.from(endDate, local),
        recurrenceRule: RecurrenceRule(
          frequency,
          interval: repeatInterval,
          endDate: recurrenceEndDate,
        ),
        reminders: [Reminder(minutes: 10)],
      );

      final result = await _calendarPlugin.createOrUpdateEvent(event);
      if (result?.isSuccess == true && result?.data != null) {
        await prefs.setString(eventKey, result!.data!);
        print("✅ Event added to calendar: ${calendar.name ?? 'Unnamed'}");
      } else {
        print("❌ Failed to add event to ${calendar.name}: ${result?.errors}");
      }
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
                  final picked = await showTimePicker(
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
                  .map((type) =>
                      DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) => setState(() => frequencyType = value!),
            ),
            Row(
              children: [
                const Text("Repeat every: "),
                const SizedBox(width: 10),
                DropdownButton<int>(
                  value: repeatInterval,
                  items: List.generate(30, (i) => i + 1)
                      .map((val) =>
                          DropdownMenuItem(value: val, child: Text("$val")))
                      .toList(),
                  onChanged: (val) => setState(() => repeatInterval = val!),
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
                          child: Text("$val ${getUnitLabel(frequencyType)}")))
                      .toList(),
                  onChanged: (val) => setState(() => repeatDuration = val!),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: submitReminderToServer,
              child: const Text("Set Reminder"),
            ),
          ],
        ),
      ),
    );
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
}
