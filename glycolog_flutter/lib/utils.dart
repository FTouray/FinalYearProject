import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Function to format the timestamp
String formatTimestamp(String timestamp) {
  final DateTime utcTime = DateTime.parse(timestamp).toUtc();
  final DateTime localTime = utcTime.toLocal();
  final DateFormat formatter = DateFormat('dd/MM/yyyy HH:mm');
  return formatter.format(localTime);
}

// Function to format DateTime and TimeOfDay
String formatDateTime(DateTime date, TimeOfDay time) {
  final DateTime dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  final DateFormat formatter = DateFormat('dd/MM/yyyy HH:mm:ss');
  return formatter.format(dateTime);
}

// Function to format DateTime
String formatDate(DateTime date) {
  final DateFormat formatter = DateFormat('dd/MM/yyyy');
  return formatter.format(date);
}

// Function to format TimeOfDay
String formatTime(TimeOfDay time) {
  final DateTime now = DateTime.now();
  final DateTime dateTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  final DateFormat formatter = DateFormat('HH:mm:ss');
  return formatter.format(dateTime);
}

// Conversion function to convert mg/dL to mmol/L
double convertToMmolL(double value) {
  return value / 18.01559; // Convert mg/dL to mmol/L
}

// Conversion function to convert mmol/L to mg/dL
double convertToMgdL(double value) {
  return value * 18.01559; // Convert mmol/L to mg/dL
}

// Function to format the glucose values based on the unit
String formatGlucoseValue(double? value, String measurementUnit) {
  if (value == null) return '-'; // Return a placeholder if the value is null
  if (measurementUnit == 'mmol/L') {
    return value.toStringAsFixed(1); // One decimal point for mmol/L
  } else {
    return value.round().toString(); // Nearest whole number for mg/dL
  }
}

/// Dynamically fetch unit from SharedPreferences and format value accordingly
Future<String> formatGlucoseDynamic(double? mgValue) async {
  if (mgValue == null) return '-';
  final prefs = await SharedPreferences.getInstance();
  final unit = prefs.getString('selectedUnit') ?? 'mg/dL';

  return unit == 'mmol/L'
      ? convertToMmolL(mgValue).toStringAsFixed(1)
      : mgValue.round().toString();
}

/// Utility to convert raw mg/dL value to preferred unit numerically
Future<double> convertToPreferredUnit(double mgValue) async {
  final prefs = await SharedPreferences.getInstance();
  final unit = prefs.getString('selectedUnit') ?? 'mg/dL';
  return unit == 'mmol/L' ? convertToMmolL(mgValue) : mgValue;
}

// Function to pick the date
Future<DateTime?> selectDate(BuildContext context, DateTime initialDate) async {
  final DateTime? pickedDate = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(2000),
    lastDate: DateTime(2101),
  );
  return pickedDate;
}

// Function to pick the time
Future<TimeOfDay?> selectTime(BuildContext context, TimeOfDay initialTime) async {
  final TimeOfDay? pickedTime = await showTimePicker(
    context: context,
    initialTime: initialTime,
  );
  return pickedTime;
}