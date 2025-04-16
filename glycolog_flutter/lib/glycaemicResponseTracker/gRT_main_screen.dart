// ignore_for_file: avoid_print

import 'package:glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:glycolog/home/base_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glycolog/utils.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fl_chart/fl_chart.dart';

class GRTMainScreen extends StatefulWidget {
  @override
  _GRTMainScreenState createState() => _GRTMainScreenState();
}

class _GRTMainScreenState extends State<GRTMainScreen> {
  bool isLoading = true;
  String? errorMessage;
  int? lastResponse;
  int? avgResponse;
  double dailyGoalProgress = 0;
  String? mealInsight;
  List<dynamic> allMealLogs = [];
  List<dynamic> insights = [];
  String measurementUnit = 'mg/dL';
  final String? apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchGlycaemicData();
  }

  Future<void> _fetchGlycaemicData() async {
    String? token = await AuthService().getAccessToken();
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/glycaemic-response/'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          lastResponse = (data['lastResponse'] as num?)?.toInt() ?? 0;
          avgResponse = (data['avgResponse'] as num?)?.toInt() ?? 0;
          dailyGoalProgress =
              (data['dailyGoalProgress'] as num?)?.toDouble() ?? 0.0;
          mealInsight = data['mealInsight'] ?? "No insights available";
          allMealLogs = data['all_meal_logs'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load data';
          isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        errorMessage = 'An error occurred: $error';
        isLoading = false;
      });
    }
  }

  Future<void> _loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      measurementUnit = prefs.getString('selectedUnit') ?? 'mg/dL';
    });
  }

  double convertToMmolL(double value) {
    return value / 18.01559;
  }

  String formatGlucoseValue(double? value) {
    if (value == null) return '-';
    if (measurementUnit == 'mmol/L') {
      return value.toStringAsFixed(1);
    } else {
      return value.round().toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return BaseScaffoldScreen(
      selectedIndex: 0,
      onItemTapped: (index) {
        final routes = ['/home', '/forum', '/settings'];
        if (index >= 0 && index < routes.length) {
          Navigator.pushNamed(context, routes[index]);
        }
      },
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    width: screenWidth,
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
                    child: Column(
                      children: [
                        Text(
                          "Glycaemic Response Overview",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            CircleDisplay(
                              value: lastResponse ?? 0,
                              label: "Last Meal GI",
                              color: Colors.blue[300]!,
                            ),
                            CircleDisplay(
                              label: "Add Meal",
                              color: Colors.blue[300]!,
                              icon: Icons.add,
                              onTap: () {
                                Navigator.pushNamed(context, '/log-meal');
                              },
                            ),
                            CircleDisplay(
                              value: avgResponse ?? 0,
                              label: "Average GI",
                              color: Colors.blue[300]!,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildGIGraph(allMealLogs.take(20).toList().reversed.toList()),
                  
                  const SizedBox(height: 30),
                  Container(
                    width: screenWidth,
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
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          "Recent Meal Logs",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 250,
                          child: allMealLogs.isNotEmpty
                              ? ListView.builder(
                                  itemCount: allMealLogs.length > 5
                                      ? 5
                                      : allMealLogs.length,
                                  itemBuilder: (context, index) {
                                    final meal = allMealLogs[index];
                                    return ListTile(
                                      title: Text(
                                          'Meal ID: ${meal['user_meal_id']}${meal['name'] != null ? ' - ${meal['name']}' : ''}'),
                                      subtitle: Text(
                                          'Timestamp: ${formatTimestamp(meal['timestamp'])}'),
                                    );
                                  },
                                )
                              : const Center(
                                  child: Text('No recent meal logs available'),
                                ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/meal-log-history');
                          },
                          child: const Text("See All Logs"),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    width: screenWidth,
                    padding: const EdgeInsets.all(16),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Notes",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (avgResponse != null && avgResponse! > 70)
                          const Text(
                            "Your average GI is high. Consider adding more low-GI foods like oats, legumes, and leafy greens to your meals.",
                            style: TextStyle(fontSize: 14),
                          )
                        else if (lastResponse != null && lastResponse! > 80)
                          const Text(
                            "Your last meal caused a high spike in glucose. Try to combine carbs with protein or fat to slow down absorption.",
                            style: TextStyle(fontSize: 14),
                          )
                        else
                          const Text(
                            "You're doing great! Keep maintaining balanced meals and staying consistent.",
                            style: TextStyle(fontSize: 14),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

 Widget _buildGIGraph(List<dynamic> logs) {
  if (logs.isEmpty) {
    return const SizedBox(
      height: 150,
      child: Center(child: Text("No GI data to display.")),
    );
  }

  final spots = logs.asMap().entries.map((e) {
    final index = e.key;
    final log = e.value;
    final gi = (log['total_glycaemic_index'] as num?)?.toDouble() ?? 0.0;
    return FlSpot(index.toDouble(), gi);
  }).toList();

  final chartWidth = (logs.length * 60).toDouble().clamp(300, 1200);
  final maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 20;

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 24),
    padding: const EdgeInsets.all(16),
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Glycaemic Index Trend (Last ${logs.length} Meals)",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartWidth.toDouble(),
            height: 320,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                clipData: FlClipData.none(),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.blueGrey.shade700..withValues(alpha: 0.5),
                    tooltipRoundedRadius: 8,
                    tooltipMargin: 10,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        final log = logs[index];
                        final date = DateTime.tryParse(log['timestamp'] ?? '');
                        final timeFormatted = date != null
                            ? "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}"
                            : "-";
                        final carbs = log['total_carbs']?.toStringAsFixed(1) ?? "-";
                        return LineTooltipItem(
                          "GI: ${spot.y.toStringAsFixed(1)}\n"
                          "Time: $timeFormatted\n"
                          "Carbs: $carbs g",
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text("Meal Date", style: TextStyle(fontWeight: FontWeight.bold)),
                    axisNameSize: 28,
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 42,
                      getTitlesWidget: (value, _) {
                        final index = value.toInt();
                        if (index < 0 || index >= logs.length) return const SizedBox.shrink();
                        final timestamp = logs[index]['timestamp'];
                        final date = DateTime.tryParse(timestamp);
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            date != null ? "${date.day}/${date.month}" : '',
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text("GI Level", style: TextStyle(fontWeight: FontWeight.bold)),
                    axisNameSize: 32,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    barWidth: 3,
                    color: Colors.blueAccent,
                    dotData: FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
}

class CircleDisplay extends StatelessWidget {
  final int? value;
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color color;

  const CircleDisplay({
    super.key,
    this.value,
    required this.label,
    this.onTap,
    this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 40, color: Colors.white)
                  : Text(
                      value != null ? "${value!.toInt()} GI" : '-',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontSize: 16, color: Colors.blue[800])),
        ],
      ),
    );
  }
}
