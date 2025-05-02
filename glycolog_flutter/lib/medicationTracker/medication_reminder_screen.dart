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
  bool _isLoadingCalendars = true;

  @override
  void initState() {
    super.initState();
    _initializeTimezone();
    _requestCalendarPermissions();
  }

  void _initializeTimezone() {
    tzdata.initializeTimeZones();
    try {
      _userLocation = tz.getLocation(DateTime.now().timeZoneName);
    } catch (_) {
      _userLocation = tz.getLocation('UTC');
    }
  }

  Future<void> _requestCalendarPermissions() async {
    final result = await _calendarPlugin.requestPermissions();
    print("🔍 Permission result: ${result.isSuccess}, granted: ${result.data}");

    if (result.isSuccess && result.data == true) {
      final calendarsResult = await _calendarPlugin.retrieveCalendars();
      print("📅 Retrieved calendars: ${calendarsResult.data?.length}");

      if (calendarsResult.isSuccess && calendarsResult.data != null) {
       final writableCalendars = calendarsResult.data!
            .where((cal) => cal.isReadOnly != true)
            .toList();


        for (final cal in writableCalendars) {
          print(
              "🗓 Calendar ID: ${cal.id}, Name: ${cal.name}, Account: ${cal.accountName}");
        }

        setState(() {
          _availableCalendars = writableCalendars;
          _selectedCalendarId = _availableCalendars.isNotEmpty
              ? _availableCalendars.first.id
              : null;
          _isLoadingCalendars = false;
        });
      } else {
        setState(() {
          _availableCalendars = [];
          _selectedCalendarId = null;
          _isLoadingCalendars = false;
        });
      }
    } else {
      print("🚫 Calendar permission not granted.");
      setState(() => _isLoadingCalendars = false);
    }
  }


  Future<void> submitReminderToServer() async {
    if (_selectedCalendarId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No calendar selected")),
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
      await _addCalendarEvent();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to set reminder")),
        );
      }
    }
  }

  Future<void> _addCalendarEvent() async {
    final prefs = await SharedPreferences.getInstance();
    final eventKey =
        'eventId_med${widget.medication["id"]}_${_selectedCalendarId}';
    final oldEventId = prefs.getString(eventKey);

    if (oldEventId != null) {
      final deleteResult =
          await _calendarPlugin.deleteEvent(_selectedCalendarId!, oldEventId);
      if (deleteResult.isSuccess && deleteResult.data == true) {
        await prefs.remove(eventKey);
      }
    }

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

    final tzStart = tz.TZDateTime(
      _userLocation,
      startDate.year,
      startDate.month,
      startDate.day,
      startDate.hour,
      startDate.minute,
    );
    final tzEnd = tzStart.add(const Duration(minutes: 5));


    RecurrenceFrequency frequency = RecurrenceFrequency.Weekly;
    if (frequencyType == "Daily") frequency = RecurrenceFrequency.Daily;
    if (frequencyType == "Monthly") frequency = RecurrenceFrequency.Monthly;

    final repeatDays = frequency == RecurrenceFrequency.Weekly
        ? repeatInterval * 7 * repeatDuration
        : frequency == RecurrenceFrequency.Daily
            ? repeatInterval * repeatDuration
            : 30 * repeatInterval * repeatDuration;

    final recurrenceEnd = tz.TZDateTime.from(
      startDate.add(Duration(days: repeatDays)),
      _userLocation,
    );

    final event = Event(
      _selectedCalendarId,
      title: 'Take ${widget.medication['name']}',
      start: tzStart,
      end: tzEnd,
      description: 'Medication reminder from Glycolog',
      recurrenceRule: RecurrenceRule(
        frequency,
        interval: repeatInterval,
        endDate: recurrenceEnd,
      ),
      reminders: [Reminder(minutes: 10)],
    );

    final result = await _calendarPlugin.createOrUpdateEvent(event);
    if (result?.isSuccess == true && result?.data != null) {
      await prefs.setString(eventKey, result!.data!);
      print("✅ Event created with ID: ${result.data}");
    } else {
      print("❌ Failed to create event: ${result?.errors}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Reminder: ${widget.medication['name']}"),
      ),
      body: _isLoadingCalendars
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_availableCalendars.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Select Calendar",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedCalendarId,
                          onChanged: (val) =>
                              setState(() => _selectedCalendarId = val),
                          items: _availableCalendars.map((cal) {
                            final label = (cal.name?.trim().isNotEmpty ?? false)
                                ? cal.name!
                                : (cal.accountName?.trim().isNotEmpty ?? false)
                                    ? 'Unnamed (${cal.accountName})'
                                    : 'Unnamed Calendar';
                            return DropdownMenuItem(
                              value: cal.id,
                              child: Text(label),
                            );
                          }).toList(),
                        ),
                        const Divider(height: 32),
                      ],
                    )
                  else
                    const Text(
                      "⚠ No writable calendars available.",
                      style: TextStyle(color: Colors.red),
                    ),
                  _buildSectionTitle(Icons.calendar_today, "Schedule Details"),
                  const SizedBox(height: 8),
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          DropdownButton<String>(
                            isExpanded: true,
                            value: selectedDay,
                            items: daysOfWeek
                                .map((day) => DropdownMenuItem(
                                    value: day, child: Text(day)))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => selectedDay = value!),
                          ),
                          const SizedBox(height: 8),
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle(Icons.repeat, "Repeat Options"),
                  const SizedBox(height: 8),
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          DropdownButton<String>(
                            isExpanded: true,
                            value: frequencyType,
                            items: frequencyTypes
                                .map((type) => DropdownMenuItem(
                                    value: type, child: Text(type)))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => frequencyType = value!),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text("Every "),
                              const SizedBox(width: 10),
                              DropdownButton<int>(
                                value: repeatInterval,
                                items: List.generate(30, (i) => i + 1)
                                    .map((val) => DropdownMenuItem(
                                        value: val, child: Text("$val")))
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => repeatInterval = val!),
                              ),
                              const SizedBox(width: 10),
                              Text(frequencyType.toLowerCase()),
                            ],
                          ),
                          Row(
                            children: [
                              const Text("For "),
                              const SizedBox(width: 10),
                              DropdownButton<int>(
                                value: repeatDuration,
                                items: [1, 2, 3, 4, 6, 8, 12]
                                    .map((val) => DropdownMenuItem(
                                        value: val,
                                        child: Text(
                                            "$val ${getUnitLabel(frequencyType)}")))
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => repeatDuration = val!),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: submitReminderToServer,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("Set Reminder",
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
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

  String getUnitLabel(String frequency) {
    switch (frequency) {
      case "Daily":
        return "days";
      case "Weekly":
        return "weeks";
      case "Monthly":
        return "months";
      default:
        return "units";
    }
  }
}
