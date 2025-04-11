// // reminder_service.dart

// import 'dart:convert';
// import 'package:Glycolog/services/auth_service.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:timezone/timezone.dart' as tz;
// import 'package:timezone/data/latest.dart' as tz;
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:flutter_dotenv/flutter_dotenv.dart';

// class ReminderService {
//   static late FlutterLocalNotificationsPlugin _notificationsPlugin;

//   static void init(FlutterLocalNotificationsPlugin plugin) {
//     _notificationsPlugin = plugin;
//     tz.initializeTimeZones();
//   }

//   static Future<void> syncRemindersWithLocalNotifications() async {
//     final token = await AuthService().getAccessToken();
//     if (token == null) {
//       print("No token found, not scheduling reminders.");
//       return;
//     }

//     final apiUrl = dotenv.env['API_URL'];
//     if (apiUrl == null) {
//       print("API_URL not found in .env");
//       return;
//     }

//     final url = Uri.parse('$apiUrl/reminders/');
//     final response = await http.get(url, headers: {
//       'Authorization': 'Bearer $token',
//     });

//     if (response.statusCode != 200) {
//       print("Failed to fetch reminders: ${response.body}");
//       return;
//     }

//     final List<dynamic> reminders = json.decode(response.body);

//     // If you want to avoid duplicates each time you sync, you might:
//     // await _notificationsPlugin.cancelAll();

//     for (var r in reminders) {
//       final dayOfWeek = r["day_of_week"];
//       final hour = r["hour"];
//       final minute = r["minute"];
//       final repeatWeeks = r["repeat_weeks"] ?? 4;
//       final medication = r["medication"];

//       // If your serializer includes medication name, use that.
//       // Otherwise we just do "Medication #ID".
//       final medicationName = "Medication #$medication";

//       await _scheduleWeeklyLocalNotifications(
//         day: _convertIntToDay(dayOfWeek),
//         hour: hour,
//         minute: minute,
//         repeatWeeks: repeatWeeks,
//         medicationName: medicationName,
//       );
//     }
//   }

//   static Day _convertIntToDay(int dayInt) {
//     switch (dayInt) {
//       case 1:
//         return Day.monday;
//       case 2:
//         return Day.tuesday;
//       case 3:
//         return Day.wednesday;
//       case 4:
//         return Day.thursday;
//       case 5:
//         return Day.friday;
//       case 6:
//         return Day.saturday;
//       case 7:
//       default:
//         return Day.sunday;
//     }
//   }

//   static Future<void> _scheduleWeeklyLocalNotifications({
//     required Day day,
//     required int hour,
//     required int minute,
//     required int repeatWeeks,
//     required String medicationName,
//   }) async {
//     final TimeOfDay timeOfDay = TimeOfDay(hour: hour, minute: minute);

//     for (int i = 0; i < repeatWeeks; i++) {
//       final DateTime firstReminder = _nextInstanceOfDayAndTime(day, timeOfDay);
//       final DateTime scheduleDate = firstReminder.add(Duration(days: 7 * i));

//       await _notificationsPlugin.zonedSchedule(
//         id,
//         "Medication Reminder",
//         "Time to take your meds!",
//         scheduledDate,
//         scheduleDate,
//         androidScheduleMode: AndroidScheduleMode.exact, // <-- new param
//         uiLocalNotificationDateInterpretation:
//             UILocalNotificationDateInterpretation.absoluteTime,
//       );
//     }
//   }

//   static DateTime _nextInstanceOfDayAndTime(Day day, TimeOfDay timeOfDay) {
//     final now = DateTime.now();
//     final int desiredWeekday = day.value; // Monday=1..Sunday=7
//     final int currentWeekday = now.weekday;

//     int dayOffset = (desiredWeekday - currentWeekday) % 7;
//     final DateTime nextDay =
//         DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));

//     return DateTime(nextDay.year, nextDay.month, nextDay.day, timeOfDay.hour,
//         timeOfDay.minute);
//   }

//   static tz.TZDateTime _toTZDateTime(DateTime dateTime) {
//     return tz.TZDateTime.from(dateTime, tz.local);
//   }

//   static int _createUniqueId(DateTime dateTime) {
//     return int.parse(
//       "${dateTime.year}"
//       "${_twoDigits(dateTime.month)}"
//       "${_twoDigits(dateTime.day)}"
//       "${_twoDigits(dateTime.hour)}"
//       "${_twoDigits(dateTime.minute)}",
//     );
//   }

//   static String _twoDigits(int n) => n.toString().padLeft(2, '0');
// }
