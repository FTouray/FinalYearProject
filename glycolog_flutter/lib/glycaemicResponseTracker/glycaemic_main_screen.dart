// ignore_for_file: avoid_print

import 'package:glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:glycolog/home/base_screen.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glycolog/utils.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fl_chart/fl_chart.dart';

class GRTMainScreen extends StatefulWidget {
  const GRTMainScreen({super.key});

  @override
  GRTMainScreenState createState() => GRTMainScreenState();
}

class GRTMainScreenState extends State<GRTMainScreen> {
  bool isLoading = true;
  String? errorMessage;
  int? lastResponse;
  int? avgResponse;
  double dailyGoalProgress = 0;
  String? mealInsight;
  List<dynamic> allMealLogs = [];
  List<dynamic> insights = [];
  String measurementUnit = 'mg/dL';
  List<String> unwellDays = [];
  final String? apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchUnwellDays();
    _fetchGlycaemicData();
  }

Future<void> fetchUnwellDays() async {
    String? token = await AuthService().getAccessToken();
    final apiUrl = dotenv.env['API_URL'];

    if (token != null) {
      try {
        final response = await http.get(
          Uri.parse('$apiUrl/health/bad-days/'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            unwellDays = List<String>.from(data['bad_days'] ?? [])
                .map((d) => DateFormat('yyyy-MM-dd').format(DateTime.parse(d)))
                .toList();
            print("🩺 Normalized Unwell Days: $unwellDays");
          });
        } else {
          // Handle error
        }
      } catch (e) {
        // Handle exception
      }
    }
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
                  _buildGIGraph(allMealLogs),

                  
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
    if (logs.isEmpty && unwellDays.isEmpty) {
      return const SizedBox(
        height: 150,
        child: Center(child: Text("No GI data to display.")),
      );
    }

    final dateFormatter = DateFormat('yyyy-MM-dd');
    final Map<String, List<Map<String, dynamic>>> dailyGroupedLogs = {};
    final Map<String, double> averagedGI = {};

    for (var log in logs) {
      final timestamp = DateTime.tryParse(log['timestamp'] ?? '');
      final gi = (log['total_glycaemic_index'] as num?)?.toDouble();
      if (timestamp == null || gi == null) continue;

      final day = dateFormatter.format(timestamp);
      dailyGroupedLogs.putIfAbsent(day, () => []).add({
        'timestamp': timestamp,
        'gi': gi,
      });
    }

    for (var entry in dailyGroupedLogs.entries) {
      final values = entry.value.map((e) => e['gi'] as double).toList();
      final averageGI = values.reduce((a, b) => a + b) / values.length;
      averagedGI[entry.key] = averageGI;
    }

    final sortedGiDates = averagedGI.keys.toList()..sort();
    if (sortedGiDates.isEmpty) return const SizedBox();

    final mostRecentDate = DateTime.parse(sortedGiDates.last);
    final earliestDate = mostRecentDate.subtract(const Duration(days: 29));
    final dateRange = List.generate(
      30,
      (i) => dateFormatter.format(earliestDate.add(Duration(days: i))),
    );

    final List<FlSpot> graphSpots = [];
    final Map<double, DateTime> xDateMap = {};
    final List<double> unwellXPositions = [];

    for (int i = 0; i < dateRange.length; i++) {
      final dateStr = dateRange[i];
      final date = DateTime.parse(dateStr);

      final x = (dateRange.length - 1 - i).toDouble();
      xDateMap[x] = date;

      if (averagedGI.containsKey(dateStr)) {
        graphSpots.add(FlSpot(x, averagedGI[dateStr]!));
      }

      if (unwellDays.contains(dateStr)) {
        unwellXPositions.add(x);
      }
    }

    final maxY = graphSpots.isNotEmpty
        ? graphSpots.map((e) => e.y).reduce((a, b) => a > b ? a : b)
        : 100;
    final chartWidth = (dateRange.length * 60).clamp(300, 2400).toDouble();
    final dateRangeDisplay =
        "${DateFormat('dd MMM').format(earliestDate)} to ${DateFormat('dd MMM').format(mostRecentDate)}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24), // 👈 spacing between cards and title
        Center(
          child: Text(
            "Glycaemic Index (Daily Avg: $dateRangeDisplay)",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
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
              width: chartWidth,
              height: 440,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: dateRange.length.toDouble(),
                  minY: 0,
                  maxY: (maxY / 20).ceil() * 20.0,
                  clipData: FlClipData.none(),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      axisNameWidget: const Text(
                        "Date",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      axisNameSize: 28,
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 42,
                        getTitlesWidget: (value, _) {
                          final date = xDateMap[value];
                          return date == null
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    DateFormat('dd/MM').format(date),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: const Text(
                        "GI Level",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      axisNameSize: 32,
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        interval: 20,
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        getTitlesWidget: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: graphSpots,
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.blueAccent,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(
                    verticalLines: unwellXPositions.map((x) {
                      return VerticalLine(
                        x: x,
                        color: Colors.purple.withValues(alpha: 0.6),
                        strokeWidth: 2,
                        dashArray: [4, 4],
                        label: VerticalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          labelResolver: (_) => 'Unwell',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) =>
                          Colors.blueGrey.shade700.withAlpha(200),
                      tooltipRoundedRadius: 8,
                      tooltipMargin: 10,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots
                            .map((spot) {
                              final date = xDateMap[spot.x];
                              if (date == null) return null;

                              final dateKey = dateFormatter.format(date);
                              final logsForDay =
                                  dailyGroupedLogs[dateKey] ?? [];
                              final avgGI =
                                  averagedGI[dateKey]?.toStringAsFixed(0);

                              final tooltipText = logsForDay.map((log) {
                                final gi = log['gi'] as double;
                                final time = log['timestamp'] as DateTime;
                                final formattedTime =
                                    "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                                return "GI: ${gi.toStringAsFixed(0)}  Time: $formattedTime";
                              }).join('\n');

                              return LineTooltipItem(
                                "$tooltipText\n\nAvg: $avgGI GI",
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            })
                            .whereType<LineTooltipItem>()
                            .toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
