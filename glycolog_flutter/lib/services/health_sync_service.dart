import 'dart:convert';
import 'package:health/health.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:Glycolog/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthSyncService {
  final Health _health = Health();
  final String? apiUrl = dotenv.env['API_URL'];

  final List<HealthDataType> _requiredTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.WORKOUT,
    HealthDataType.TOTAL_CALORIES_BURNED,
  ];

  Future<bool> requestPermissions() async {
    await _health.configure();
    final sdkStatus = await _health.getHealthConnectSdkStatus();
    if (sdkStatus != HealthConnectSdkStatus.sdkAvailable) return false;

    final activity = await Permission.activityRecognition.request();
    final location = await Permission.location.request();
    if (!activity.isGranted || !location.isGranted) return false;

    final granted = await _health.requestAuthorization(
      _requiredTypes,
      permissions: _requiredTypes.map((_) => HealthDataAccess.READ).toList(),
    );

    return granted;
  }

  Future<List<HealthDataPoint>> _getLast24HoursData() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 1));

    print("📆 Fetching last 24h data from $start to $now");

    final records = await _health.getHealthDataFromTypes(
      types: _requiredTypes,
      startTime: start,
      endTime: now,
    );

    final deduplicated = _health.removeDuplicates(records);
    print("📦 Last 24h records fetched: ${records.length}");
    print("🧹 Deduplicated count: ${deduplicated.length}");

    if (deduplicated.isNotEmpty) {
      print(
          "🧪 Sample: ${deduplicated.first.type} at ${deduplicated.first.dateFrom} = ${deduplicated.first.value}");
    }

    return deduplicated;
  }

  Future<List<HealthDataPoint>> _getHistoricalData(
      {Duration range = const Duration(days: 30)}) async {
    final now = DateTime.now();
    final start = now.subtract(range);

    print("📆 Fetching historical data from $start to $now");

    final records = await _health.getHealthDataFromTypes(
      types: _requiredTypes,
      startTime: start,
      endTime: now,
    );

    final deduplicated = _health.removeDuplicates(records);
    print("📦 Historical records fetched: ${records.length}");
    print("🧹 Deduplicated count: ${deduplicated.length}");

    if (deduplicated.isNotEmpty) {
      print(
          "🧪 Sample: ${deduplicated.first.type} at ${deduplicated.first.dateFrom} = ${deduplicated.first.value}");
    }

    return deduplicated;
  }


  Map<HealthDataType, List<HealthDataPoint>> _groupDataPoints(
      List<HealthDataPoint> points) {
    final Map<HealthDataType, List<HealthDataPoint>> grouped = {};
    for (var point in points) {
      grouped.putIfAbsent(point.type, () => []).add(point);
    }
    return grouped;
  }

  double _extractNumericValue(HealthValue value) {
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    } else {
      print("⚠️ Unsupported HealthValue type: ${value.runtimeType}");
      return 0.0;
    }
  }

List<Map<String, dynamic>> _transformGroupedData(
    Map<HealthDataType, List<HealthDataPoint>> grouped) {
  final workouts = grouped[HealthDataType.WORKOUT] ?? [];

  print("🏋️ Found ${workouts.length} workouts");

  final heartRates = grouped[HealthDataType.HEART_RATE]?.map((p) {
    return _extractNumericValue(p.value);
  }).toList() ?? [];

  final avgHeartRate = heartRates.isNotEmpty
      ? heartRates.reduce((a, b) => a + b) / heartRates.length
      : null;

  final sleepSeconds = grouped[HealthDataType.SLEEP_ASLEEP]?.fold(
          0, (sum, p) => sum + p.dateTo.difference(p.dateFrom).inSeconds) ??
      0;

  final sleepHours =
      double.parse((sleepSeconds / 3600).toStringAsFixed(2));

  final allSteps = grouped[HealthDataType.STEPS] ?? [];
  final fallbackStart = allSteps.isNotEmpty
      ? allSteps.first.dateFrom
      : DateTime.now().subtract(const Duration(hours: 1));
  final fallbackEnd = allSteps.isNotEmpty
      ? allSteps.last.dateTo
      : DateTime.now();

  final totalSteps = allSteps.fold(
      0, (sum, p) => sum + _extractNumericValue(p.value).toInt());

  if (workouts.isEmpty) {
    print("⚠️ No workouts found. Creating fallback workout entry.");

    return [
      {
        "activity_type": "General Activity",
        "start_time": fallbackStart.toIso8601String(),
        "end_time": fallbackEnd.toIso8601String(),
        "duration_minutes":
            fallbackEnd.difference(fallbackStart).inMinutes,
        "steps": totalSteps,
        "heart_rate": avgHeartRate ?? 0,
        "calories_burned": 0,
        "distance_meters": 0,
        "sleep_hours": sleepHours,
        "is_fallback": true,
      }
    ];
  }

  return workouts.map((w) {
    String type = "Workout";
    if (w.value is WorkoutHealthValue) {
      final activity = (w.value as WorkoutHealthValue).workoutActivityType;
      type = activity.toString().split('.').last;
    }

    final start = w.dateFrom;
    final end = w.dateTo;
    final duration = end.difference(start).inMinutes;

    final steps = grouped[HealthDataType.STEPS]
            ?.where((p) =>
                p.dateFrom.isAfter(start) && p.dateTo.isBefore(end))
            .fold(0, (sum, p) =>
                sum + _extractNumericValue(p.value).toInt()) ??
        0;

    final hrValues = grouped[HealthDataType.HEART_RATE]
            ?.where((p) =>
                p.dateFrom.isAfter(start) && p.dateTo.isBefore(end))
            .map((p) => _extractNumericValue(p.value))
            .toList() ??
        [];

    final avgHR = hrValues.isNotEmpty
      ? (hrValues.reduce((a, b) => a + b) / hrValues.length).round()
      : 0;


     // Calories burned (rounded to nearest int)
      final calories = grouped[HealthDataType.ACTIVE_ENERGY_BURNED]
              ?.where(
                  (p) => p.dateFrom.isAfter(start) && p.dateTo.isBefore(end))
              .fold(0.0, (sum, p) => sum + _extractNumericValue(p.value)) ??
          0.0;

// Distance (converted to kilometers and rounded to 2 decimals)
      final distanceMeters = grouped[HealthDataType.DISTANCE_DELTA]
              ?.where(
                  (p) => p.dateFrom.isAfter(start) && p.dateTo.isBefore(end))
              .fold(0.0, (sum, p) => sum + _extractNumericValue(p.value)) ??
          0.0;

      final distanceKm =
          double.parse((distanceMeters / 1000).toStringAsFixed(2));

    
    final workoutSummary = w.workoutSummary;

    final data = {
      "activity_type": type,
      "start_time": start.toIso8601String(),
      "end_time": end.toIso8601String(),
      "duration_minutes": duration,
      "steps": steps,
      "heart_rate": avgHR,
      "calories_burned": calories.round(),
      "distance_meters": distanceKm,
    };

    if (w == workouts.last) {
      data["sleep_hours"] = sleepHours;
    }

    return data;
  }).toList();
}


Future<bool> syncToBackend({bool force = false}) async {
    final token = await AuthService().getAccessToken();
    if (token == null || apiUrl == null) {
      print("❌ Missing token or API URL");
      return false;
    }

    try {
      final alreadySynced = await hasAlreadySyncedToday();
      final firstTime = await isFirstTimeSync();
      print("🔄 Already synced today? $alreadySynced | First time: $firstTime");

      final shouldSync = force || firstTime || !alreadySynced;
      if (!shouldSync) {
        print("⏭️ Skipping sync (already synced today)");
        return true;
      }

      // ⏳ Use a longer range if it's first time
      final dataPoints = await _getHistoricalData(
        range: firstTime ? const Duration(days: 60) : const Duration(days: 30),
      );

      final grouped = _groupDataPoints(dataPoints);
      final payloads = _transformGroupedData(grouped);

      for (final data in payloads) {
        final response = await http.post(
          Uri.parse('$apiUrl/health/log/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(data),
        );

        if (response.statusCode != 201) {
          print("❌ Failed to sync: ${response.body}");
          return false;
        }
      }

      print("✅ Sync complete.");
      await markSyncCompleteToday();
      if (firstTime) await markFirstSyncDone();
      return true;
    } catch (e) {
      print("❌ Sync error: $e");
      return false;
    }
  }


 Future<bool> hasAlreadySyncedToday() async {
  final prefs = await SharedPreferences.getInstance();
  final lastSynced = prefs.getString('last_sync_date');
  final today = DateTime.now().toIso8601String().split('T').first;
  return lastSynced == today;
}

Future<void> markSyncCompleteToday() async {
  final prefs = await SharedPreferences.getInstance();
  final today = DateTime.now().toIso8601String().split('T').first;
  await prefs.setString('last_sync_date', today);
}

Future<bool> isFirstTimeSync() async {
    final prefs = await SharedPreferences.getInstance();
    return !prefs.containsKey('has_ever_synced');
  }

  Future<void> markFirstSyncDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_ever_synced', true);
  }


}
