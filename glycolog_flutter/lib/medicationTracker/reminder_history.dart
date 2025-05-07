import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReminderHistoryScreen extends StatefulWidget {
  const ReminderHistoryScreen({super.key});

  @override
  State<ReminderHistoryScreen> createState() => _ReminderHistoryScreenState();
}

class _ReminderHistoryScreenState extends State<ReminderHistoryScreen> {
  final DeviceCalendarPlugin _calendarPlugin = DeviceCalendarPlugin();
  Map<String, List<Event>> groupedEvents = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchGroupedReminders();
  }

  Future<void> fetchGroupedReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys =
        prefs.getKeys().where((key) => key.startsWith('eventId_med'));

    final now = DateTime.now();
    final Map<String, List<Event>> tempMap = {};

    for (final key in allKeys) {
      final storedValue = prefs.getString(key);
      if (storedValue == null || !storedValue.contains('|')) continue;

      final parts = storedValue.split('|');
      if (parts.length != 2) continue;

      final calendarId = parts[0];
      final eventId = parts[1];

      final result = await _calendarPlugin.retrieveEvents(
        calendarId,
        RetrieveEventsParams(
          startDate: now.subtract(const Duration(days: 365)),
          endDate: now,
          eventIds: [eventId],
        ),
      );

      if (result.isSuccess && result.data != null) {
        for (final event in result.data!) {
          if (event.start != null && event.start!.isBefore(now)) {
            final title = event.title ?? 'Unknown Medication';
            tempMap.putIfAbsent(title, () => []).add(event);
          }
        }
      }
    }

    tempMap.forEach(
      (key, list) => list.sort((a, b) => b.start!.compareTo(a.start!)),
    );

    setState(() {
      groupedEvents = tempMap;
      isLoading = false;
    });
  }

  String formatDateTime(DateTime dt) {
    return "${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reminder History")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : groupedEvents.isEmpty
              ? const Center(child: Text("No past reminders found."))
              : Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ListView(
                    children: groupedEvents.entries.map((entry) {
                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ExpansionTile(
                          leading:
                              const Icon(Icons.medication, color: Colors.teal),
                          title: Text(
                            entry.key,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          children: entry.value.map((event) {
                            return ListTile(
                              leading:
                                  const Icon(Icons.history, color: Colors.grey),
                              title: Text(formatDateTime(event.start!)),
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  ),
                ),
    );
  }
}
