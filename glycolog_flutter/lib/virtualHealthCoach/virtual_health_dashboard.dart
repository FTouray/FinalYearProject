import 'dart:convert';
import 'package:Glycolog/home/base_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:Glycolog/services/health_sync_service.dart';
import 'package:Glycolog/services/auth_service.dart';

extension StringCasingExtension on String {
  String capitalize() => "${this[0].toUpperCase()}${substring(1)}";
}
class VirtualHealthDashboard extends StatefulWidget {
  const VirtualHealthDashboard({Key? key}) : super(key: key);

  @override
  State<VirtualHealthDashboard> createState() => _VirtualHealthDashboardState();
}

class _VirtualHealthDashboardState extends State<VirtualHealthDashboard> {
  bool isLoading = true;
  bool isSyncing = false;
  Map<String, dynamic>? todayData;
  Map<String, dynamic>? trendData;
  List<Map<String, dynamic>> history = [];
  final String? apiUrl = dotenv.env['API_URL'];
  String trendType = "weekly";
  List<Map<String, dynamic>> _filteredHistory = [];
  bool isRefreshingSummary = false;
  ScrollController _scrollController = ScrollController(); // Add to state


IconData _getActivityIcon(String activityType) {
    final lower = activityType.toLowerCase();

    if (lower == 'walking') {
      return Icons.directions_walk;
    } else if (lower == 'running') {
      return Icons.directions_run;
    } else if (lower == 'cycling') {
      return Icons.directions_bike;
    } else if (lower == 'swimming') {
      return Icons.pool;
    } else if (lower == 'yoga') {
      return Icons.self_improvement;
    } else if (lower == 'hiking') {
      return Icons.terrain;
    } else if (lower == 'workout') {
      return Icons.fitness_center;
    } else {
      return Icons.fitness_center;
    }
  }

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  Future<void> _initDashboard() async {
    final token = await AuthService().getAccessToken();
    if (token == null) return;

    await _syncHealthData(token);
    await _loadDashboard(token);

    // Auto-refresh trend if outdated
    final String? trendEnd = trendData?['end_date'];
    if (trendEnd != null) {
      final endDate = DateTime.tryParse(trendEnd);
      if (endDate != null && DateTime.now().difference(endDate).inDays >= 7) {
        await _refreshTrendSummary();
      }
    }
  }

Future<void> _refreshTrendSummary() async {
    final token = await AuthService().getAccessToken();
    if (token == null) return;

    try {
      final refreshed = await http.get(
        Uri.parse("$apiUrl/health/trends/$trendType/?refresh=true"),
        headers: {"Authorization": "Bearer $token"},
      );

      setState(() {
        trendData = jsonDecode(refreshed.body)["trend"];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Health trend summary refreshed.")),
      );
    } catch (e) {
      print("Error refreshing trend summary: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to refresh health summary.")),
      );
    }
  }


  Future<void> _syncHealthData(String token) async {
    setState(() => isSyncing = true);
    await HealthSyncService().syncToBackend(force: true);
    setState(() => isSyncing = false);
  }

  Future<void> _loadDashboard(String token) async {
    setState(() => isLoading = true);

    try {
      final todayRes = await http.get(
        Uri.parse("$apiUrl/health/today/"),
        headers: {"Authorization": "Bearer $token"},
      );

      final trendRes = await http.get(
        Uri.parse("$apiUrl/health/trends/$trendType/"),
        headers: {"Authorization": "Bearer $token"},
      );

      final histRes = await http.get(
        Uri.parse("$apiUrl/dashboard/summary/"),
        headers: {"Authorization": "Bearer $token"},
      );

      final fullHistory = _mapTrend(jsonDecode(histRes.body)["trend_data"],
          excludeFallback: false)
        ..sort((a, b) => b['date'].compareTo(a['date']));
      final filteredHistory = _mapTrend(jsonDecode(histRes.body)["trend_data"])
        ..sort((a, b) => b['date'].compareTo(a['date']));


      setState(() {
        todayData = jsonDecode(todayRes.body);
        trendData = jsonDecode(trendRes.body)["trend"];
        history = fullHistory; // used for graphs
        _filteredHistory = filteredHistory; // used for summaries
      });
    } catch (e) {
      print("Dashboard load failed: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not load dashboard data.")),
      );
    }

    setState(() => isLoading = false);
  }

List<Map<String, dynamic>> _mapTrend(Map<String, dynamic> trend,
      {bool excludeFallback = true}) {
    final List<Map<String, dynamic>> result = [];

    trend.forEach((date, dayData) {
      final activityList = dayData['activities'] as List<dynamic>;

      for (var activity in activityList) {
        final isFallback = activity['is_fallback'] == true;
        final activityType = activity['activity_type']?.toLowerCase() ?? "";

        final isSleep = activityType.contains("sleep");

        // Skip displaying sleep activities
        if (isSleep) continue;

        // Exclude fallback activities if the flag is set
        if (excludeFallback && isFallback) continue;

        result.add({
          "date": date,
          ...activity,
        });
      }

      // Add sleep_hours at date-level for use in trend summaries or graphs
      final sleepHours = dayData["sleep_hours"];
      if (sleepHours != null) {
        result.add({
          "date": date,
          "activity_type": "sleep_summary",
          "sleep_hours": sleepHours,
        });
      }
    });

    return result;
  }

Future<void> _loadPastTrends() async {
    final token = await AuthService().getAccessToken();
    if (token == null) return;

    try {
      final res = await http.get(
        Uri.parse("$apiUrl/health/trends/?period_type=$trendType"),
        headers: {"Authorization": "Bearer $token"},
      );

      final data = jsonDecode(res.body);
      final List<Map<String, dynamic>> trends =
          List<Map<String, dynamic>>.from(data["trends"]);
      trends.sort((a, b) => b["start_date"].compareTo(a["start_date"]));
      if (trends.isNotEmpty) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (context) {
            return DraggableScrollableSheet(
              expand: false,
              builder: (_, controller) => ListView.builder(
                controller: controller,
                itemCount: data["trends"].length,
                itemBuilder: (_, index) {
                  final trend = data["trends"][index];
                  return ListTile(
                    title: Text(
                      "${trend['start_date']} to ${trend['end_date']}",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "Steps: ${trend['avg_steps']}, Sleep: ${trend['avg_sleep_hours']} hrs, Glucose: ${trend['avg_glucose_level']?.toStringAsFixed(1) ?? 'N/A'}",
                    ),
                    onTap: () {
                        bool expanded = false;
                        showDialog(
                          context: context,
                          builder: (_) => StatefulBuilder(
                            builder: (context, setState) => AlertDialog(
                              title: Text(
                                  "Summary (${trend['start_date']} - ${trend['end_date']})"),
                              content: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Steps: ${trend['avg_steps']}"),
                                    Text(
                                        "Sleep: ${trend['avg_sleep_hours']} hrs"),
                                    Text(
                                        "Heart Rate: ${trend['avg_heart_rate']?.round() ?? 'N/A'} bpm"),
                                    Text(
                                        "Glucose: ${trend['avg_glucose_level']?.toStringAsFixed(1) ?? 'N/A'} mg/dL"),
                                    Text(
                                        "Sessions: ${trend['total_exercise_sessions']}"),
                                    const SizedBox(height: 10),
                                    if (trend['ai_summary'] != null)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text("AI Summary:",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text(
                                            expanded
                                                ? trend['ai_summary'] : trend['ai_summary'].toString().split("\n").take(3).join("\n") + "...",
                                            style: const TextStyle(
                                                fontStyle: FontStyle.italic),
                                          ),
                                          if (trend['ai_summary']
                                                  .toString()
                                                  .split("\n")
                                                  .length >
                                              3)
                                            TextButton(
                                              onPressed: () => setState(
                                                  () => expanded = !expanded),
                                              child: Text(expanded
                                                  ? "Show Less"
                                                  : "Show More"),
                                            ),
                                        ],
                                      )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                  );
                },
              ),
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No previous summaries found.")),
        );
      }
    } catch (e) {
      print("Failed to load past trends: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not load previous summaries.")),
      );
    }
  }

  Future<void> _filterByDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      final String pickedDateStr = picked.toIso8601String().split("T").first;

      final matches =
          history.where((entry) => entry['date'] == pickedDateStr).toList();

      if (matches.isNotEmpty) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text("Workouts on ${_formatDate(pickedDateStr)}"),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: matches.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${entry['activity_type']?.toString().capitalize() ?? 'Activity'}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...entry.entries
                          .where((e) =>
                              e.key != 'date' && e.key != 'activity_type')
                          .map((e) => _buildFormattedEntry(e.key, e.value))
                          .toList(),
                      const Divider(height: 20),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No data found for selected date.")),
        );
      }
    }
  }



Widget _buildTrendSummary() {
    if (trendData == null) return const SizedBox();

    String formatDate(String isoDate) {
      try {
        final dt = DateTime.parse(isoDate);
        return "${dt.day} ${_monthName(dt.month)} ${dt.year}";
      } catch (e) {
        return isoDate;
      }
    }

    final String start = formatDate(trendData!['start_date']);
    final String end = formatDate(trendData!['end_date']);
    final DateTime? endDate = DateTime.tryParse(trendData!['end_date']);
    final int daysOld =
        endDate != null ? DateTime.now().difference(endDate).inDays : 999;

    // Badge logic
    Color badgeColor;
    String badgeText;
    if (daysOld < 7) {
      badgeColor = Colors.green.shade100;
      badgeText = "Up to Date";
    } else if (daysOld < 30) {
      badgeColor = Colors.orange.shade100;
      badgeText = "$daysOld Days Old";
    } else {
      badgeColor = Colors.red.shade100;
      badgeText = "Outdated";
    }

    final int steps = trendData!['avg_steps'] ?? 0;
    final double sleep = (trendData!['avg_sleep_hours'] ?? 0).toDouble();
    final int sessions = trendData!['total_exercise_sessions'] ?? 0;
    final double? hr = trendData!['avg_heart_rate']?.toDouble();
    final double? glucose = trendData!['avg_glucose_level']?.toDouble();
    final String? summary = trendData!['ai_summary'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text("Weekly Health Summary",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text("Period: $start to $end"),
            Text("• Avg Steps: $steps"),
            Text("• Avg Sleep: ${sleep.toStringAsFixed(1)} hrs"),
            Text("• Avg Heart Rate: ${hr?.round() ?? 'N/A'} bpm"),
            Text(
                "• Avg Glucose: ${glucose?.toStringAsFixed(1) ?? 'N/A'} mg/dL"),
            Text("• Exercise Sessions: $sessions"),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: isRefreshingSummary
                      ? null
                      : () async {
                          setState(() => isRefreshingSummary = true);
                          final token = await AuthService().getAccessToken();
                          final refreshed = await http.get(
                            Uri.parse(
                                "$apiUrl/health/trends/$trendType/?refresh=true"),
                            headers: {"Authorization": "Bearer $token"},
                          );
                          setState(() {
                            trendData = jsonDecode(refreshed.body)["trend"];
                            isRefreshingSummary = false;
                          });

                          _scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    "Health summary successfully refreshed!")),
                          );
                        },
                  icon: isRefreshingSummary
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text("Refresh Summary"),
                ),
                TextButton.icon(
                  onPressed: _loadPastTrends,
                  icon: const Icon(Icons.history),
                  label: const Text("View Previous Summaries"),
                ),
              ],
            ),


            if (summary != null && summary.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("AI Coach Insights:",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(summary.trim(),
                        style: const TextStyle(fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }


Widget _buildGraph(String title, String metric, Color color) {
    String getYAxisLabel(String metric) {
      switch (metric) {
        case 'heart_rate':
          return 'bpm';
        case 'sleep_hours':
          return 'hrs';
        case 'steps':
          return 'steps';
        default:
          return '';
      }
    }

    // Extract y-values and compute dynamic chart height
    final yValues = history
        .map((e) => (e[metric] is num) ? (e[metric] as num).toDouble() : 0.0)
        .toList();
    final maxY =
        yValues.isNotEmpty ? yValues.reduce((a, b) => a > b ? a : b) : 100;
    final chartHeight = (maxY > 200) ? 400.0 : (maxY > 100 ? 350.0 : 300.0);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: (history.length * 50).toDouble().clamp(300, 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text("Y Axis (${getYAxisLabel(metric)})",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(
                      height: chartHeight,
                      child: LineChart(
                        LineChartData(
                          clipData:
                              FlClipData.none(), // tooltips allowed outside
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (touchedSpot) => Colors.grey.withOpacity(0.8),
                              tooltipRoundedRadius: 8,
                              tooltipMargin: 12,
                              fitInsideHorizontally: false,
                              fitInsideVertically: false,
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  final entry = history[spot.x.toInt()];
                                  final date = entry['date'];
                                  final type =
                                      entry['activity_type'] ?? "Workout";
                                  final time = entry['start_time'] != null
                                      ? _formatDateTime(
                                          entry['start_time'].toString())
                                      : "";
                                  final yLabel = getYAxisLabel(metric);
                                  return LineTooltipItem(
                                    "Activity: ${type.toString().capitalize()}\n"
                                    "Date: $date ${time.isNotEmpty ? '\nTime: $time' : ''}\n"
                                    "${metric.replaceAll('_', ' ').capitalize()}: ${spot.y.toStringAsFixed(1)} $yLabel",
                                    const TextStyle(color: Colors.white),
                                  );
                                }).toList();
                              },
                            ),
                            handleBuiltInTouches: true,
                          ),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                interval: 1,
                                getTitlesWidget: (value, _) {
                                  final index = value.toInt();
                                  if (index < 0 || index >= history.length)
                                    return const SizedBox();
                                  final date = history[index]['date'];
                                  return Text(date.split('-').last); // show day
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                              ),
                            ),
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: true),
                          gridData: FlGridData(show: true),
                          minY: 0,
                          maxY: maxY + 10, // padding top to prevent clipping
                          lineBarsData: [
                            LineChartBarData(
                              spots: history.asMap().entries.map((e) {
                                final value = (e.value[metric] is num)
                                    ? (e.value[metric] as num).toDouble()
                                    : 0.0;
                                return FlSpot(e.key.toDouble(), value);
                              }).toList(),
                              isCurved: true,
                              color: color,
                              dotData: FlDotData(show: true),
                              belowBarData: BarAreaData(show: false),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text("X Axis (Date)",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }



Widget _buildTodaySummary() {
    if (todayData == null || todayData!.isEmpty) {
      final yesterday = history.isNotEmpty ? history.last : null;
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("No data for today yet!",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (yesterday != null) ...[
                const Text("Here's your last recorded data from yesterday:",
                    style: TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 6),
                ...yesterday.entries
                    .where((e) => e.key != 'date' && e.key != 'activity_type')
                    .map((e) => _buildFormattedEntry(e.key, e.value))
              ] else
                const Text("No data found from previous days either."),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Today's Summary",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...todayData!.entries
                .where((e) => e.key != 'is_fallback')
                .map((e) => _buildFormattedEntry(e.key, e.value)),
          ],
        ),
      ),
    );
  }


String _formatValue(String label, dynamic value) {
    if (label.toLowerCase().contains("heart_rate") && value is num) {
      return value.round().toString();
    }
    return value.toString();
  }

  String _formatDistance(dynamic value) {
    if (value == null) return "0 km";
    try {
      final km = value as num;
      return "${km.toStringAsFixed(2)} km";
    } catch (e) {
      return "0 km";
    }
  }


  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.replaceAll("_", " ").toUpperCase()),
          Text(_formatValue(label, value)),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              "Explore History",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          if (_filteredHistory.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("No workouts to display yet."),
            )
          else
            ..._filteredHistory.map((entry) {
              final activityType =
                  (entry['activity_type'] ?? '').toString().toLowerCase();
              if (activityType.contains("sleep"))
                return const SizedBox.shrink();

              return ListTile(
                leading:
                    Icon(_getActivityIcon(entry['activity_type'] ?? 'workout')),
                title: Text(
                  "${entry['activity_type']?.toString().capitalize() ?? 'Activity'} • ${_formatDate(entry['date'])}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                    "Steps: ${entry['steps'] ?? 0} • Distance: ${_formatDistance(entry['distance_km'])} • Calories: ${entry['calories_burned']?.toStringAsFixed(1) ?? '0'} kcal"),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text("Details for ${_formatDate(entry['date'])}"),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: entry.entries
                            .where((e) => e.key != 'date')
                            .map((e) => _buildFormattedEntry(e.key, e.value))
                            .toList(),
                      ),
                    ),
                  );
                },
              );
            }),

        ],
      ),
    );
  }
  
  Widget _buildFormattedEntry(String key, dynamic value) {
    String formattedValue;

    switch (key) {
      case 'distance_km':
        formattedValue = _formatDistance(value);
        break;
      case 'calories_burned':
        formattedValue = "${(value as num?)?.toStringAsFixed(1) ?? '0'} kcal";
        break;
      case 'heart_rate':
        formattedValue = "${(value as num?)?.round()} bpm";
        break;
      case 'start_time':
      case 'end_time':
        formattedValue = _formatDateTime(value.toString());
        break;
      default:
        formattedValue = value.toString();
    }

    // Skip showing fallback field
    if (key == 'is_fallback') return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.black),
          children: [
            TextSpan(
              text: "${_prettifyKey(key)}: ",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: formattedValue),
          ],
        ),
      ),
    );
  }

  String _prettifyKey(String key) {
    return key
        .replaceAll("_", " ")
        .split(" ")
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(" ");
  }

  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      return "${_twoDigits(dateTime.day)}-${_twoDigits(dateTime.month)}-${dateTime.year} "
          "${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}:${_twoDigits(dateTime.second)}";
    } catch (e) {
      return isoString;
    }
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');


  String _formatDate(String date) {
    final parts = date.split('-');
    if (parts.length < 3) return date;
    final formatted =
        DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    return "${formatted.day} ${_monthName(formatted.month)}";
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
  
  @override
  Widget build(BuildContext context) {
    return BaseScaffoldScreen(
      selectedIndex: 0,
      onItemTapped: (index) {
        final routes = ['/home', '/forum', '/settings'];
        if (index >= 0 && index < routes.length) {
          Navigator.pushNamed(context, routes[index]);
        }
      },
      body: Scaffold(
        appBar: AppBar(
          title: const Text("Health Coach Dashboard"),
          backgroundColor: Colors.blue[800],
          actions: [
            IconButton(
              icon: isSyncing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
              onPressed: () async {
                final token = await AuthService().getAccessToken();
                if (token != null) await _syncHealthData(token);
                await _loadDashboard(token!);
              },
            ),
            IconButton(
              icon: const Icon(Icons.chat),
              onPressed: () => Navigator.pushNamed(context, '/chatbot'),
              tooltip: "Chat with Coach",
            ),
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: _filterByDate,
              tooltip: "Pick a day",
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  final token = await AuthService().getAccessToken();
                  if (token != null) await _syncHealthData(token);
                  await _loadDashboard(token!);
                },
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  children: [
                    _buildTodaySummary(),
                    _buildTrendSummary(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: DropdownButton<String>(
                        value: trendType,
                        items: ['weekly', 'monthly'].map((type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text("View $type trend"),
                          );
                        }).toList(),
                        onChanged: (value) async {
                          if (value != null) {
                            setState(() => trendType = value);
                            final token = await AuthService().getAccessToken();
                            await _loadDashboard(token!);
                          }
                        },
                      ),
                    ),
                    _buildGraph("Step Trend", "steps", Colors.blue),
                    _buildGraph(
                        "Heart Rate Trend", "heart_rate", Colors.redAccent),
                    _buildGraph("Sleep Trend", "sleep_hours", Colors.purple),
                    _buildHistorySection(),
                  ],
                ),
              ),
      ),
    );
  }

}
