import 'package:glycolog/services/auth_service.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzData;

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
  String? _selectedCalendarId;
  late tz.Location _userLocation;

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
    _initializeTimezone();
    _requestCalendarPermissions();
  }

  void _initializeTimezone() {
    tzData.initializeTimeZones();
    try {
      _userLocation = tz.getLocation(DateTime.now().timeZoneName);
    } catch (_) {
      _userLocation = tz.getLocation('UTC');
    }
  }

  Future<void> _requestCalendarPermissions() async {
    final result = await _calendarPlugin.requestPermissions();

    if (result.isSuccess && result.data == true) {
      final calendarsResult = await _calendarPlugin.retrieveCalendars();

      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        final writableCalendars = calendarsResult.data!
            .where((cal) => cal.isReadOnly == false)
            .toList();

        if (writableCalendars.isEmpty) {
          print("⚠️ No writable calendars found.");
        } else {
          print("✅ Writable calendars:");
          for (final cal in writableCalendars) {
            print(
                "📅 ${cal.name} | ID: ${cal.id} | Account: ${cal.accountName}");
          }
        }

        setState(() {
          _availableCalendars = writableCalendars;
          if (_availableCalendars.isNotEmpty) {
            _selectedCalendarId = _availableCalendars.first.id;
            print("✅ Selected calendar ID: $_selectedCalendarId");
          }
        });
      }
    } else {
      print("🚫 Calendar permission not granted.");
    }
  }

  Future<void> submitReminderToServer() async {
    if (_selectedCalendarId == null) {
      print("❗ Reminder not submitted: No calendar selected yet");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No calendar selected")),
      );
      return;
    }

    final dayInt = daysOfWeek.indexOf(selectedDay) + 1;
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
    if (_selectedCalendarId == null) {
      print("❗ No calendar selected");
      return;
    }

    final now = DateTime.now();
    final dayOffset = (daysOfWeek.indexOf(selectedDay) - now.weekday + 7) % 7;

    final startDate = DateTime(now.year, now.month, now.day)
        .add(Duration(days: dayOffset))
        .copyWith(hour: selectedTime.hour, minute: selectedTime.minute);

    final tzStartDate = tz.TZDateTime.from(startDate, _userLocation);
    final tzEndDate = tzStartDate.add(const Duration(minutes: 5));

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

    final repeatDays = frequency == RecurrenceFrequency.Weekly
        ? repeatInterval * 7 * repeatDuration
        : frequency == RecurrenceFrequency.Daily
            ? repeatInterval * repeatDuration
            : 30 * repeatInterval * repeatDuration;

    final recurrenceEndDate = tz.TZDateTime.from(
      startDate.add(Duration(days: repeatDays)),
      _userLocation,
    );

    final event = Event(
      _selectedCalendarId,
      title: 'Take ${widget.medication['name']}',
      description: 'Medication reminder from Glycolog',
      start: tzStartDate,
      end: tzEndDate,
      recurrenceRule: RecurrenceRule(
        frequency,
        interval: repeatInterval,
        endDate: recurrenceEndDate,
      ),
    );

    final result = await _calendarPlugin.createOrUpdateEvent(event);

    if (result?.isSuccess == true && result?.data != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'eventId_med${widget.medication["id"]}',
        result!.data!,
      );
      print("✅ Event created with ID: ${result.data}");
    } else {
      print("❌ Failed to create event: ${result?.errors}");
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
            if (_availableCalendars.isNotEmpty && _selectedCalendarId != null)
              DropdownButton<String>(
                value: _selectedCalendarId,
                onChanged: (val) {
                  setState(() => _selectedCalendarId = val);
                },
                items: _availableCalendars.map((cal) {
                  return DropdownMenuItem(
                    value: cal.id,
                    child: Text(cal.name ?? "Unnamed Calendar"),
                  );
                }).toList(),
              ),
            DropdownButton<String>(
              value: selectedDay,
              items: daysOfWeek.map((day) {
                return DropdownMenuItem(value: day, child: Text(day));
              }).toList(),
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
                  items: List.generate(30, (index) => index + 1)
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
            )
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
