import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:Glycolog/services/health_sync_service.dart';
import 'package:Glycolog/services/auth_service.dart';

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


  IconData _getActivityIcon(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return Icons.directions_walk;
      case 'running':
        return Icons.directions_run;
      case 'cycling':
        return Icons.directions_bike;
      case 'swimming':
        return Icons.pool;
      case 'yoga':
        return Icons.self_improvement;
      case 'hiking':
        return Icons.terrain;
      case 'workout':
      default:
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
          excludeFallback: false);
      final filteredHistory = _mapTrend(jsonDecode(histRes.body)["trend_data"]);

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
    final mapped = trend.entries
        .map((e) =>
            {"date": e.key as String, ...e.value as Map<String, dynamic>})
        .toList();

    return excludeFallback
        ? mapped.where((entry) => entry["is_fallback"] != true).toList()
        : mapped;
  }



  Future<void> _filterByDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      final selected = history.firstWhere(
        (entry) => entry['date'] == picked.toString().split(" ")[0],
        orElse: () => {},
      );

      if (selected.isNotEmpty) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text("Data for ${selected['date']}"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: selected.entries
                  .where((e) => e.key != 'date')
                  .map((e) => Text("${e.key.toUpperCase()}: ${e.value}"))
                  .toList(),
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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Trend Summary",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
                "From ${trendData!['start_date']} to ${trendData!['end_date']}"),
            Text("Avg Steps: ${trendData!['avg_steps'] ?? 'N/A'}"),
            Text("Avg Sleep: ${trendData!['avg_sleep_hours'] ?? 'N/A'} hrs"),
            Text(
                "Avg Heart Rate: ${trendData!['avg_heart_rate'] ?? 'N/A'} bpm"),
            Text(
                "Exercise Sessions: ${trendData!['total_exercise_sessions'] ?? 'N/A'}"),

            const SizedBox(height: 6),
            if (trendData!['ai_summary'] != null)
              Text("AI Summary: ${trendData!['ai_summary']}")
          ],
        ),
      ),
    );
  }

  Widget _buildGraph(String title, String metric, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= history.length)
                            return const SizedBox();
                          final date = history[index]['date'];
                          return Text(
                              date.toString().split('-').last); // day of month
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles:
                          SideTitles(showTitles: true, reservedSize: 32),
                    ),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  gridData: FlGridData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: history.asMap().entries.map((e) {
                        final value = (e.value[metric] is num) ? (e.value[metric] as num).toDouble() : 0.0;
                        return FlSpot(e.key.toDouble(), value);
                      }).toList(),
                      isCurved: true,
                      color: color,
                      dotData: FlDotData(show: false),
                    )
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
                    .where((e) => e.key != 'date')
                    .map((e) => _buildDataRow(e.key, e.value.toString()))
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
                .map((e) => _buildDataRow(e.key, e.value.toString()))
          ],
        ),
      ),
    );
  }


  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label.replaceAll("_", " ").toUpperCase()), Text(value)],
      ),
    );
  }

  Widget _buildHistoryTable() {
  final recent = _filteredHistory.take(5).toList();

  return Card(
    margin: const EdgeInsets.only(top: 10),
    child: Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Recent Workouts",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...recent.map((e) => ListTile(
                title: Text(_formatDate(e['date'])),
                subtitle: Text(
                    "Steps: ${e['steps']} • Distance: ${e['distance_meters']} m • Calories: ${e['calories_burned']} kcal"),
              ))
        ],
      ),
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
            ..._filteredHistory.map((entry) => ListTile(
                  leading: Icon(
                      _getActivityIcon(entry['activity_type'] ?? 'workout')),
                  title: Text(
                    "${(entry['activity_type'] ?? 'Activity').toString().toUpperCase()} • ${_formatDate(entry['date'])}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                      "Steps: ${entry['steps'] ?? 0} • Distance: ${entry['distance_meters'] ?? 0} m • Calories: ${entry['calories_burned'] ?? 0} kcal"),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title:
                            Text("Details for ${_formatDate(entry['date'])}"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: entry.entries
                              .where((e) => e.key != 'date')
                              .map((e) => Text(
                                  "${e.key.replaceAll("_", " ").toUpperCase()}: ${e.value}"))
                              .toList(),
                        ),
                      ),
                    );
                  },
                )),
        ],
      ),
    );
  }

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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Health Coach Dashboard"),
        actions: [
          IconButton(
            icon: isSyncing
                ? const CircularProgressIndicator()
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
                  _buildHistoryTable(),
                  _buildHistorySection(),
                ],
              ),
            ),
    );
  }
}
