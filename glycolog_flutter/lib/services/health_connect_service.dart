import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:health/health.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class HealthConnectService {
  final String? apiUrl = dotenv.env['API_URL'];

  List<HealthDataType> get requiredTypes => [
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.DISTANCE_DELTA,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.WORKOUT,
        HealthDataType.TOTAL_CALORIES_BURNED, // Important!
      ];

  /// Request permissions for required health data types
  Future<bool> requestPermissions() async {
    final health = Health();

    // Step 1: Configure Health plugin
    await health.configure();

    // Step 2: Check if Health Connect is available
    final sdkStatus = await health.getHealthConnectSdkStatus();
    print("📱 Health Connect status: ${sdkStatus?.name}");

    if (sdkStatus != HealthConnectSdkStatus.sdkAvailable) {
      print("❌ Health Connect not available or supported.");
      return false;
    }

    // Step 3: Request Android runtime permissions
    final activityPermission = await Permission.activityRecognition.request();
    final locationPermission = await Permission.location.request();

    if (activityPermission != PermissionStatus.granted ||
        locationPermission != PermissionStatus.granted) {
      print("❌ Required runtime permissions denied.");
      return false;
    }

    // Step 4: Request Health Connect permissions
    final permissions =
        requiredTypes.map((_) => HealthDataAccess.READ).toList();

    final granted = await health.requestAuthorization(
      requiredTypes,
      permissions: permissions,
    );

    print("📨 Health Connect permission granted: $granted");

    // Step 5: Confirm final permission check
    final hasPermissions = await health.hasPermissions(
      requiredTypes,
      permissions: permissions,
    );

    print("✅ Final permission check: $hasPermissions");

    return hasPermissions == true;
  }

  /// Fetch health data from the last 24 hours
 Future<List<Map<String, dynamic>>> fetchHealthData() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    print("📆 Fetching health data from $yesterday to $now");

    final records = await Health().getHealthDataFromTypes(
      types: requiredTypes,
      startTime: yesterday,
      endTime: now,
    );

    print("📦 Raw records fetched: ${records.length}");

    for (var record in records) {
      print(
          "🔹 [${record.type}] Value: ${record.value}, From: ${record.dateFrom}, To: ${record.dateTo}");
    }

    final deduped = Health().removeDuplicates(records);
    print("🧼 Deduplicated records: ${deduped.length}");

    final Map<HealthDataType, List<HealthDataPoint>> grouped = {};
    for (var point in deduped) {
      grouped.putIfAbsent(point.type, () => []).add(point);
    }

    for (var entry in grouped.entries) {
      print("📂 Grouped ${entry.key.name}: ${entry.value.length} points");
    }

    final workouts = grouped[HealthDataType.WORKOUT] ?? [];

    final heartRates = grouped[HealthDataType.HEART_RATE]
            ?.map((p) => p.value as double)
            .toList() ??
        [];
    final avgHeartRate = heartRates.isNotEmpty
        ? heartRates.reduce((a, b) => a + b) / heartRates.length
        : null;

    if (avgHeartRate != null) {
      print("❤️ Average heart rate: ${avgHeartRate.toStringAsFixed(1)}");
    }

    final sleepSeconds = grouped[HealthDataType.SLEEP_ASLEEP]?.fold<int>(
          0,
          (sum, p) => sum + p.dateTo.difference(p.dateFrom).inSeconds,
        ) ??
        0;

    print("😴 Total sleep (seconds): $sleepSeconds");

    if (workouts.isEmpty) {
      print("⚠️ No workouts found — no data will be sent.");
      return [];
    }

    final resultList = workouts.map((workout) {
      final type = workout.workoutSummary?.workoutType ?? "Workout";
      final start = workout.dateFrom;
      final end = workout.dateTo;
      final duration = end.difference(start).inMinutes;

      final map = {
        "steps": grouped[HealthDataType.STEPS]
                ?.fold<int>(0, (sum, p) => sum + (p.value as int)) ??
            0,
        "heart_rate": avgHeartRate ?? 0.0,
        "calories_burned": workout.workoutSummary?.totalEnergyBurned ?? 0.0,
        "distance_meters": workout.workoutSummary?.totalDistance ?? 0.0,
        "sleep_hours": (sleepSeconds / 3600).toStringAsFixed(2),
        "activity_type": type,
        "start_time": start.toIso8601String(),
        "end_time": end.toIso8601String(),
        "duration_minutes": duration,
      };

      print("📤 Final workout data to send: $map");
      return map;
    }).toList();

    return resultList;
  }


  /// Send health data to backend
  Future<bool> sendToBackend(String userToken) async {
    try {
      final activities = await fetchHealthData();
      print("🚀 Sending ${activities.length} activities to backend");

      for (var activity in activities) {
        final response = await http.post(
          Uri.parse('$apiUrl/store_health_data/'),
          headers: {
            'Authorization': 'Bearer $userToken',
            'Content-Type': 'application/json'
          },
          body: jsonEncode(activity),
        );

        if (response.statusCode != 201) {
          print("❌ Failed for ${activity['activity_type']}: ${response.body}");
          return false;
        }

        print("✅ Sent ${activity['activity_type']} to backend");
      }

      return true;
    } catch (e) {
      print("❌ Error sending health data: $e");
      return false;
    }
  }
}
