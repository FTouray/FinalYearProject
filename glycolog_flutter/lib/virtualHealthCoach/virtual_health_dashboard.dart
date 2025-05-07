import 'dart:convert';
import 'package:glycolog/home/base_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:glycolog/services/health_sync_service.dart';
import 'package:glycolog/services/auth_service.dart';

extension StringCasingExtension on String {
  String capitalize() => "${this[0].toUpperCase()}${substring(1)}";
}
class VirtualHealthDashboard extends StatefulWidget {
  const VirtualHealthDashboard({super.key});

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
  final ScrollController _scrollController = ScrollController(); // Add to state
  Set<String> _badDays = {};


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
    await _loadBadFeelingDays();

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

      if (!mounted) return;

      setState(() {
        trendData = jsonDecode(refreshed.body)["trend"];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Health trend summary refreshed.")),
      );
    } catch (e) {
      if (!mounted) return;
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

      Map<String, dynamic> trendJson = {};
      try {
        trendJson = jsonDecode(trendRes.body);
      } catch (_) {}

      final fullHistory = _mapTrend(jsonDecode(histRes.body)["trend_data"],
          excludeFallback: false)
        ..sort((a, b) => b['date'].compareTo(a['date']));
      final filteredHistory = _mapTrend(jsonDecode(histRes.body)["trend_data"])
        ..sort((a, b) => b['date'].compareTo(a['date']));

      setState(() {
        todayData = jsonDecode(todayRes.body);
        trendData = trendJson["trend"] ?? {};
        history = fullHistory;
        _filteredHistory = filteredHistory;
      });
    } catch (e) {
      print("Dashboard load failed: $e");

      if (!mounted) return;
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

      if (!mounted) return; 

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
                      "Steps: ${trend['avg_steps']}, Glucose: ${trend['avg_glucose_level']?.toStringAsFixed(1) ?? 'N/A'}",
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
                                                ? trend['ai_summary'] : "${trend['ai_summary'].toString().split("\n").take(3).join("\n")}...",
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
      if (!mounted) return;
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

    if (!mounted) return; 

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
                        entry['activity_type']?.toString().capitalize() ?? 'Activity',
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
                          ,
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

void _refreshSummary() async {
    setState(() => isRefreshingSummary = true);

    final token = await AuthService().getAccessToken();

    final refreshed = await http.get(
      Uri.parse("$apiUrl/health/trends/$trendType/?refresh=true"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (!mounted) return;

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
        content: Text("Health summary successfully refreshed!"),
      ),
    );
  }

Future<void> _loadBadFeelingDays() async {
    final token = await AuthService().getAccessToken();
    if (token == null) return;

    final response = await http.get(
      Uri.parse("$apiUrl/health/bad-days/"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _badDays = Set<String>.from(data["bad_days"]);
        print("Bad feeling days loaded: $_badDays");
      });
    }
  }

Widget _buildTrendSummary() {
    if (trendData == null) return const SizedBox();

    final startStr = trendData?['start_date'] as String? ?? '';
    final endStr = trendData?['end_date'] as String? ?? '';

    final String start = _formatDate(startStr);
    final String end = _formatDate(endStr);
    final DateTime? endDate = (endStr.isNotEmpty) ? DateTime.tryParse(endStr) : null;
    final int daysOld =
        (endDate != null) ? DateTime.now().difference(endDate).inDays : 999;

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
    final int sessions = trendData!['total_exercise_sessions'] ?? 0;
    final double? hr = trendData!['avg_heart_rate']?.toDouble();
    final double? glucose = trendData!['avg_glucose_level']?.toDouble();
    final String summary = (trendData?['ai_summary'] ?? '').toString();
    final List<dynamic> aiItems =
        List.from(trendData!['ai_summary_items'] ?? []);
    aiItems.sort(
        (a, b) => (b['score'] ?? 0).compareTo(a['score'] ?? 0)); // Prioritize

    bool showFullSummary = false;

    return StatefulBuilder(
      builder: (context, setState) {
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
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text("Period: $start to $end"),
                Text("• Avg Steps: $steps"),
                Text("• Avg Heart Rate: ${hr?.round() ?? 'N/A'} bpm"),
                Text(
                    "• Avg Glucose: ${glucose?.toStringAsFixed(1) ?? 'N/A'} mg/dL"),
                Text("• Exercise Sessions: $sessions"),
                const SizedBox(height: 12),

                // Controls
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: isRefreshingSummary ? null : _refreshSummary,
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

                const SizedBox(height: 12),

                const Text("💡 Key AI Recommendations",
                    style: TextStyle(fontWeight: FontWeight.w600)),

                const SizedBox(height: 6),

                if (aiItems.isEmpty)
                  const Text("No AI insights available.")
                else
                  ...aiItems.take(3).map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          "• ${item['text']}",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: item['score'] == 3
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: item['score'] == 3
                                ? Colors.red[800]
                                : item['score'] == 2
                                    ? Colors.orange[800]
                                    : Colors.black87,
                          ),
                        ),
                      )),

                if (summary.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.notes),
                      label: Text(showFullSummary
                          ? "Hide Full Summary"
                          : "View Full Summary"),
                      onPressed: () =>
                          setState(() => showFullSummary = !showFullSummary),
                    ),
                  ),
                ],

                if (showFullSummary)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      summary.trim(),
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

Widget _buildGraph(String title, String metric, Color color) {
    String getYAxisLabel(String metric) {
      switch (metric) {
        case 'heart_rate':
          return 'bpm';
        case 'steps':
          return 'steps';
        default:
          return 'metric';
      }
    }

    final Set<String> allDates = {
      ...history.map((e) => e['date'] as String),
      ..._badDays,
    };

    final List<String> sortedDates = allDates.toList()
      ..sort((a, b) => b.compareTo(a));
    final Map<String, int> dateToX = {
      for (int i = 0; i < sortedDates.length; i++) sortedDates[i]: i,
    };

    final List<FlSpot> spots = sortedDates.map((date) {
      final entry =
          history.firstWhere((e) => e['date'] == date, orElse: () => {});
      final value =
          (entry[metric] is num) ? (entry[metric] as num).toDouble() : 0.0;
      return FlSpot(dateToX[date]!.toDouble(), value);
    }).toList();

    final yValues = spots.map((e) => e.y).toList();
    final maxY =
        (yValues.isNotEmpty ? yValues.reduce((a, b) => a > b ? a : b) : 100)
            .ceilToDouble();
    final chartHeight = 300 + (maxY * 1.0).clamp(0, 250); // scales with data


    final unwellLines = _badDays.where(dateToX.containsKey).map((date) {
      return VerticalLine(
        x: dateToX[date]!.toDouble(),
        color: Colors.red.withAlpha(80),
        strokeWidth: 2,
        dashArray: [6, 4],
        label: VerticalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          labelResolver: (_) => 'Unwell',
          style: const TextStyle(fontSize: 10, color: Colors.red),
        ),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Text(
            title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                blurRadius: 8,
                color: Colors.grey.shade300,
                spreadRadius: 3,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: (sortedDates.length * 60).clamp(300, 1200).toDouble(),
              height: chartHeight.toDouble(),
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0),
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY + 10,
                  clipData: FlClipData.none(),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  extraLinesData: ExtraLinesData(verticalLines: unwellLines),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: Text(getYAxisLabel(metric),
                          style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis,
                      ),
                      axisNameSize: 28,
                      sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42,
                          getTitlesWidget: (value, meta) {
                            final text = value >= 1000
                                ? "${(value / 1000).toStringAsFixed(1)}k"
                                : value.toInt().toString();
                            return Text(
                              text,
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: const Text("Date",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      axisNameSize: 35,
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: 1,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index < 0 || index >= sortedDates.length)
                            return const SizedBox();
                          final date = sortedDates[index];
                          final parts = date.split("-");
                          final formatted = (parts.length == 3)
                              ? "${parts[2]}/${parts[1]}"
                              : date;
                          final isUnwell = _badDays.contains(date);
                          return Column(
                            children: [
                              if (isUnwell)
                                const Icon(Icons.circle, color: Colors.red, size: 6),
                              Transform.rotate(
                                  angle:
                                      -0.5,
                                  child: Text(
                                    formatted,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),

                            ],
                          );
                        },
                      ),
                    ),
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (_) => Colors.grey.withAlpha(180),
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final date = sortedDates[spot.x.toInt()];
                          final entry = history.firstWhere(
                              (e) => e['date'] == date,
                              orElse: () => {});
                          final val = entry[metric];
                          return LineTooltipItem(
                            val != null
                                ? "$metric: ${val.toString()} ${getYAxisLabel(metric)}\nDate: $date"
                                : "Date: $date",
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3,
                      color: color,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            ),
            ),
          ),
      ],
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


// String _formatValue(String label, dynamic value) {
//     if (label.toLowerCase().contains("heart_rate") && value is num) {
//       return value.round().toString();
//     }
//     return value.toString();
//   }

  String _formatDistance(dynamic value) {
    if (value == null) return "0 km";
    try {
      final km = value as num;
      return "${km.toStringAsFixed(2)} km";
    } catch (e) {
      return "0 km";
    }
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
              if (activityType.contains("sleep")) {
                return const SizedBox.shrink();
              }

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
    final isEmptyState = !isLoading &&
        (todayData == null || todayData!.isEmpty) &&
        (trendData == null || trendData!.isEmpty) &&
        history.isEmpty;

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
          automaticallyImplyLeading: false, 
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
            : isEmptyState
                ? const Center(
                    child: Text(
                      "📭 No health data available.\nConnect your device and sync to begin.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  )
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
                                final token =
                                    await AuthService().getAccessToken();
                                await _loadDashboard(token!);
                              }
                            },
                          ),
                        ),
                        _buildGraph("Step Trend", "steps", Colors.blueAccent),
                        _buildGraph(
                            "Heart Rate Trend", "heart_rate", Colors.purpleAccent),
                        // _buildGraph(
                        //     "Sleep Trend", "sleep_hours", Colors.purple),
                        _buildHistorySection(),
                      ],
                    ),
                  ),
      ),
    );
  }
}
