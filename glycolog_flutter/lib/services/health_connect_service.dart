import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:health/health.dart';
import 'package:http/http.dart' as http;

class HealthConnectService {
  final Health _health = Health();
  final String? apiUrl = dotenv.env['API_URL'];

  List<HealthDataType> get requiredTypes => [
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.DISTANCE_DELTA,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.WORKOUT,
      ];

  Future<bool> requestPermissions() async {
    return await _health.requestAuthorization(requiredTypes);
  }

  Future<List<Map<String, dynamic>>> fetchHealthData() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    final records =
        _health.removeDuplicates(await _health.getHealthDataFromTypes(
      types: requiredTypes,
      startTime: yesterday,
      endTime: now,
    ));

    final Map<HealthDataType, List<HealthDataPoint>> grouped = {};
    for (var point in records) {
      grouped.putIfAbsent(point.type, () => []).add(point);
    }

    final workouts = grouped[HealthDataType.WORKOUT] ?? [];
    final heartRates = grouped[HealthDataType.HEART_RATE]
            ?.map((p) => p.value as double)
            .toList() ??
        [];
    final avgHeartRate = heartRates.isNotEmpty
        ? heartRates.reduce((a, b) => a + b) / heartRates.length
        : null;

    final sleepSeconds = grouped[HealthDataType.SLEEP_ASLEEP]?.fold<int>(
          0,
          (sum, p) => sum + p.dateTo.difference(p.dateFrom).inSeconds,
        ) ??
        0;

    if (workouts.isEmpty) return [];

    return workouts.map((workout) {
      final type = workout.workoutSummary?.workoutType ?? "Workout";
      final start = workout.dateFrom;
      final end = workout.dateTo;
      final duration = end.difference(start).inMinutes;

      return {
        "steps": grouped[HealthDataType.STEPS]
                ?.fold<int>(0, (sum, p) => sum + (p.value as int)) ??
            0,
        "heart_rate": avgHeartRate ?? 0.0,
        "calories_burned": workout.workoutSummary?.totalEnergyBurned ?? 0.0,
        "distance_meters": workout.workoutSummary?.totalDistance ?? 0.0,
        "sleep_hours": sleepSeconds / 3600,
        "activity_type": type,
        "start_time": start.toIso8601String(),
        "end_time": end.toIso8601String(),
        "duration_minutes": duration,
      };
    }).toList();
  }

  Future<void> sendToBackend(String token) async {
    final activities = await fetchHealthData();

    for (var activity in activities) {
      final res = await http.post(
        Uri.parse('$apiUrl/store_health_data/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(activity),
      );
      if (res.statusCode == 201) {
        print("Synced: ${activity['activity_type']}");
      } else {
        print("Error syncing: ${res.body}");
      }
    }
  }
}
