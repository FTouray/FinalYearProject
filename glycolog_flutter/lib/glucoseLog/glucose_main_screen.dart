import 'package:glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Importing the chart package
import 'package:http/http.dart' as http; // For making API requests
import 'package:intl/intl.dart';
import 'dart:convert'; // For JSON handling
import 'package:shared_preferences/shared_preferences.dart'; // For retrieving user settings
import '../home/base_screen.dart'; // Import BaseScreen
import 'package:glycolog/utils.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GlucoseLogScreen extends StatefulWidget {
  const GlucoseLogScreen({super.key});

  @override
  GlucoseLogScreenState createState() => GlucoseLogScreenState();
}

class GlucoseLogScreenState extends State<GlucoseLogScreen> {
  double? lastLog; // Changed to nullable double for safety
  double? averageLog; // Changed to nullable double for safety
  List<Map<String, dynamic>> glucoseLogs =
      []; // List to hold the full glucose log data
  String measurementUnit = 'mg/dL'; // Default measurement unit
  bool isLoading = true; // To show loading indicator while fetching data
  String? errorMessage; // To hold error messages if any
  List<FlSpot> graphData = []; // Define graphData variable
  List<FlSpot> fullGlucoseGraphData = [];
  List<Map<String, dynamic>> fullGlucoseLogs = [];
  List<Map<String, dynamic>> glucosePredictions = [];
  String? predictionError;
  bool isInsulinDependent = false;
  List<String> unwellDays = [];

  @override
  void initState() {
    super.initState();
    _loadUserSettings(); // Load user settings to get the preferred measurement unit
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchGlucoseLogs(); // Fetch the glucose logs when the screen is displayed
    fetchUnwellDays();
    fetchFullGlucoseTimeline();
    fetchGlucosePredictions();
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
            unwellDays = List<String>.from(data['bad_days'] ?? []);
          });
        } else {
          // Handle error
        }
      } catch (e) {
        // Handle exception
      }
    }
  }

  // Fetch user's preferred measurement unit
  Future<void> _loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      measurementUnit =
          prefs.getString('selectedUnit') ?? 'mg/dL'; // Default to mg/dL
      isInsulinDependent = prefs.getBool('isInsulinDependent') ?? false;
    });
  }

  // Safe parsing for double values, returns null if the value cannot be parsed
  double? parseDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  // Fetch glucose logs from the server
  Future<void> fetchGlucoseLogs() async {
    String? token = await AuthService().getAccessToken();
    final apiUrl = dotenv.env['API_URL'];

    if (token != null) {
      try {
        final response = await http.get(
          Uri.parse('$apiUrl/glucose-log/'),
          headers: {
            'Authorization': 'Bearer $token', // Include token in headers
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          setState(() {
            lastLog = parseDouble(data['lastLog']);
            averageLog = parseDouble(data['averageLog']);
            glucoseLogs = List<Map<String, dynamic>>.from(data['logs'] ?? []);

            // Sort logs by timestamp (latest first)
            glucoseLogs.sort((a, b) => DateTime.parse(b['timestamp'])
                .compareTo(DateTime.parse(a['timestamp'])));

            // Update last log value
            lastLog = glucoseLogs.isNotEmpty
                ? parseDouble(glucoseLogs.first['glucose_level'])
                : null;

            // Calculate the average glucose log
            if (glucoseLogs.isNotEmpty) {
              double total = glucoseLogs.fold(
                  0.0,
                  (sum, log) =>
                      sum + (parseDouble(log['glucose_level']) ?? 0.0));
              averageLog = total / glucoseLogs.length;
            } else {
              averageLog = null;
            }

            // Apply unit conversion if necessary
            if (measurementUnit == 'mmol/L') {
              lastLog = lastLog != null ? convertToMmolL(lastLog!) : null;
              averageLog =
                  averageLog != null ? convertToMmolL(averageLog!) : null;
              for (var log in glucoseLogs) {
                log['glucose_level'] = log['glucose_level'] != null
                    ? convertToMmolL(parseDouble(log['glucose_level']) ?? 0.0)
                    : null;
              }
            }

            // Update the graph data points
            graphData = getGraphData();

            isLoading = false; // Data has been loaded
          });
        } else {
          setState(() {
            errorMessage = 'Failed to load glucose logs.';
            isLoading = false; // Stop loading
          });
        }
      } catch (e) {
        setState(() {
          errorMessage = 'An error occurred: $e';
          isLoading = false; // Stop loading
        });
      }
    } else {
      setState(() {
        errorMessage = 'No valid token found. Please log in again.';
        isLoading = false;
      });
    }
  }

  // Filter logs for today's date
  List<Map<String, dynamic>> filterLogsForToday(
      List<Map<String, dynamic>> logs) {
    DateTime now = DateTime.now();
    return logs.where((log) {
      DateTime logDate = DateTime.parse(log['timestamp']);
      return logDate.year == now.year &&
          logDate.month == now.month &&
          logDate.day == now.day;
    }).toList();
  }

  Future<void> fetchFullGlucoseTimeline() async {
    String? token = await AuthService().getAccessToken();
    final apiUrl = dotenv.env['API_URL'];

    if (token != null) {
      try {
        final res = await http.get(
          Uri.parse('$apiUrl/glucose/combined-timeline/'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (res.statusCode == 200) {
          final List<dynamic> data = json.decode(res.body);

          // Sort all logs by timestamp descending
          data.sort((a, b) => DateTime.parse(b['timestamp'])
              .compareTo(DateTime.parse(a['timestamp'])));

          final Map<String, List<double>> dailyValues = {};

          for (var entry in data) {
            try {
              final timestamp = DateTime.parse(entry['timestamp']);
              final dateKey = DateFormat('yyyy-MM-dd').format(timestamp);

              final glucose =
                  double.tryParse(entry['glucose_level'].toString());
              if (glucose == null) continue;

              final adjusted = measurementUnit == 'mmol/L'
                  ? convertToMmolL(glucose)
                  : glucose;

              dailyValues.putIfAbsent(dateKey, () => []).add(adjusted);
            } catch (_) {
              continue;
            }
          }

          final sortedEntries = dailyValues.entries.toList()
            ..sort((a, b) => b.key.compareTo(a.key)); // newest first
          final last30Entries = sortedEntries.take(30).toList();

          setState(() {
            fullGlucoseGraphData = [];
            fullGlucoseLogs = [];

            print("📋 Reversed last30Entries order (newest to oldest):");
            for (int i = 0; i < last30Entries.length; i++) {
              final entry = last30Entries[i];
              final date = DateTime.parse(entry.key);
              final avg =
                  entry.value.reduce((a, b) => a + b) / entry.value.length;

              final x = (last30Entries.length - 1 - i).toDouble();

              print(
                  "➡️ i: $i, Reversed x: $x, Date: ${date.toIso8601String()}, Avg: ${avg.toStringAsFixed(2)}");

              fullGlucoseGraphData.add(FlSpot(x, avg));
              fullGlucoseLogs.add({
                "date": date.toIso8601String(),
                "average": avg,
              });
            }

            print("✅ Final Graph Data Points:");
            for (var spot in fullGlucoseGraphData) {
              print("  FlSpot(x: ${spot.x}, y: ${spot.y.toStringAsFixed(2)})");
            }
          });
          print("✅ Final points: ${fullGlucoseGraphData.length}");
        }
      } catch (e) {
        print("Failed to fetch glucose timeline: $e");
      }
    }
  }

  Future<void> fetchGlucosePredictions() async {
    String? token = await AuthService().getAccessToken();
    final apiUrl = dotenv.env['API_URL'];

    if (token != null) {
      try {
        final response = await http.get(
          Uri.parse('$apiUrl/glucose-prediction/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'success') {
            setState(() {
              glucosePredictions =
                  List<Map<String, dynamic>>.from(data['predictions']);
            });
          } else {
            setState(() {
              predictionError =
                  data['message'] ?? 'Unable to fetch predictions.';
            });
          }
        } else {
          setState(() {
            predictionError = 'Failed to load predictions.';
          });
        }
      } catch (e) {
        setState(() {
          predictionError = 'An error occurred: $e';
        });
      }
    } else {
      setState(() {
        predictionError = 'No valid token found. Please log in again.';
      });
    }
  }

  bool isPredictionSpikeLikely() {
    const spikeThresholdMg = 180;
    const spikeThresholdMmol = 10.0;

    final threshold =
        measurementUnit == 'mmol/L' ? spikeThresholdMmol : spikeThresholdMg;

    return glucosePredictions.any((pred) {
      final yhat = double.tryParse(pred['yhat'].toString()) ?? 0;
      final converted = measurementUnit == 'mmol/L' ? yhat / 18.01559 : yhat;
      return converted > threshold;
    });
  }

  // Add a new glucose log entry
  void addNewLog(Map<String, dynamic> newLog) {
    setState(() {
      // Add the new log to the list
      glucoseLogs.add(newLog);

      // Update lastLog and averageLog values
      lastLog = parseDouble(newLog['glucose_level']);
      averageLog = (averageLog != null && glucoseLogs.isNotEmpty)
          ? ((averageLog! * (glucoseLogs.length - 1) + lastLog!) /
              glucoseLogs.length)
          : lastLog;

      // Re-filter today's logs for the graph
      glucoseLogs = filterLogsForToday(glucoseLogs);
      // Update the graph data points
      graphData = getGraphData();

      // Apply unit conversion if necessary
      if (measurementUnit == 'mmol/L') {
        lastLog = lastLog != null ? convertToMmolL(lastLog!) : null;
        averageLog = averageLog != null ? convertToMmolL(averageLog!) : null;
        for (var log in glucoseLogs) {
          log['glucose_level'] = log['glucose_level'] != null
              ? convertToMmolL(parseDouble(log['glucose_level']) ?? 0.0)
              : null;
        }
      }
    });
  }

  // Determine the point color based on glucose level
  Color getPointColor(double glucoseLevel) {
    if (glucoseLevel < (measurementUnit == 'mg/dL' ? 80 : 4.4)) {
      return Colors.green; // Low
    } else if (glucoseLevel > (measurementUnit == 'mg/dL' ? 180 : 10.0)) {
      return Colors.red; // High
    }
    return Colors.blue; // Normal
  }

  // Function to get graph data points (only for today)
  List<FlSpot> getGraphData() {
    List<Map<String, dynamic>> todayLogs = filterLogsForToday(glucoseLogs);
    return todayLogs.map((log) {
      DateTime logDate = DateTime.parse(log['timestamp']);
      double hour =
          logDate.hour + logDate.minute / 60.0; // Convert time to hours
      return FlSpot(hour, parseDouble(log['glucose_level']) ?? 0.0);
    }).toList();
  }

  // Get the highest glucose level and round it up
  double getMaxY() {
    if (glucoseLogs.isEmpty) return 10.0;
    double maxGlucose = glucoseLogs.fold<double>(0.0, (previousMax, log) {
      double? level = log['glucose_level'];
      return level != null && level > previousMax ? level : previousMax;
    });
    return (maxGlucose.ceilToDouble()); // Round to the next highest integer
  }

  // Function to get individual point decorators
  List<LineChartBarData> getLineChartBarData() {
    final spots = getGraphData();

    return [
      LineChartBarData(
        spots: spots,
        isCurved: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, _, __, ___) {
            return FlDotCirclePainter(
              radius: 6,
              color: getPointColor(spot.y),
              strokeColor: Colors.black,
              strokeWidth: 2,
            );
          },
        ),
        color: Colors.blue, // Line color
        barWidth: 3,
        belowBarData: BarAreaData(
          show: true,
          color: Colors.blue.withValues(alpha: 0.3),
        ),
        showingIndicators: List.generate(spots.length, (index) => index),
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool showGlucoseAlert =
        glucosePredictions.isNotEmpty && isPredictionSpikeLikely();

    return BaseScaffoldScreen(
      selectedIndex: 0,
      showGlucoseAlert: showGlucoseAlert,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
// Glucose Overview
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
                          "Glucose Log Overview",
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
                              value: lastLog ?? 0.0,
                              label: "Last Log",
                              color: getPointColor(lastLog ?? 0.0),
                              measurementUnit: measurementUnit,
                              formattedValue:
                                  formatGlucoseValue(lastLog, measurementUnit),
                            ),
                            CircleDisplay(
                              value: null,
                              label: "Add Log",
                              color: Colors.blue[300]!,
                              measurementUnit: measurementUnit,
                              onTap: () =>
                                  Navigator.pushNamed(context, '/add-log'),
                              icon: Icons.add,
                            ),
                            CircleDisplay(
                              value: averageLog ?? 0.0,
                              label: "Average",
                              color: getPointColor(averageLog ?? 0.0),
                              measurementUnit: measurementUnit,
                              formattedValue: formatGlucoseValue(
                                  averageLog, measurementUnit),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  buildPredictionCard(screenWidth),

                  const SizedBox(height: 30),
                  // Glucose Log Today Title
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Center(
                      child: Text(
                        "📈 Glucose Today",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),

                  // Graph Section (Glucose Today)
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
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
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          width: screenWidth * 2,
                          padding: const EdgeInsets.all(16.0),
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(show: true),
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(color: Colors.grey),
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  axisNameWidget:
                                      Text('Glucose Level ($measurementUnit)'),
                                  axisNameSize: 30,
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    interval: getMaxY() / 5,
                                    getTitlesWidget: (value, meta) {
                                      return Text('${value.toInt()}');
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  axisNameWidget: const Text('Time (24h)'),
                                  axisNameSize: screenWidth / 20,
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 2,
                                    getTitlesWidget: (value, meta) {
                                      final hour = value.toInt();
                                      return SideTitleWidget(
                                        meta: meta,
                                        fitInside: SideTitleFitInsideData
                                            .fromTitleMeta(meta),
                                        child: Transform.translate(
                                          offset: const Offset(-10, 5),
                                          child: Transform.rotate(
                                            angle: -45 * 3.1416 / 180,
                                            child: Text(
                                              hour < 10
                                                  ? '0$hour:00'
                                                  : '$hour:00',
                                              style:
                                                  const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                              ),
                              minX: 0,
                              maxX: fullGlucoseGraphData.length.toDouble() + 10,
                              minY: 0,
                              maxY: getMaxY(),
                              lineBarsData: getLineChartBarData(),
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  tooltipRoundedRadius: 8,
                                  tooltipPadding: const EdgeInsets.all(8),
                                  tooltipMargin: 10,
                                  fitInsideHorizontally: true,
                                  fitInsideVertically: true,
                                  getTooltipItems: (touchedSpots) {
                                    return touchedSpots.map((spot) {
                                      final log = glucoseLogs.firstWhere(
                                        (log) =>
                                            DateTime.parse(log['timestamp'])
                                                    .hour ==
                                                spot.x.toInt() &&
                                            DateTime.parse(log['timestamp'])
                                                    .minute ==
                                                ((spot.x - spot.x.toInt()) * 60)
                                                    .toInt(),
                                        orElse: () => {},
                                      );
                                      final dateTime =
                                          DateTime.parse(log['timestamp']);
                                      final formattedTime =
                                          DateFormat('HH:mm').format(dateTime);
                                      return LineTooltipItem(
                                        'Glucose: ${spot.y.toStringAsFixed(1)}\nTime: $formattedTime',
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  buildTimelineGlucoseGraph(screenWidth),

                  const SizedBox(height: 30),

                  // Recent Logs
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
                          "Recent Glucose Logs",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 250,
                          child: glucoseLogs.isNotEmpty
                              ? ListView.builder(
                                  itemCount: glucoseLogs.length > 5
                                      ? 5
                                      : glucoseLogs.length,
                                  itemBuilder: (context, index) {
                                    final log = glucoseLogs[index];
                                    return ListTile(
                                      title: Text(
                                        'Glucose Level: ${log['glucose_level']?.toStringAsFixed(measurementUnit == 'mg/dL' ? 0 : 1) ?? 'N/A'} $measurementUnit',
                                      ),
                                      subtitle: Text(
                                        'Date & Time: ${formatTimestamp(log['timestamp'])}',
                                      ),
                                    );
                                  },
                                )
                              : const Center(
                                  child: Text(
                                    'No recent glucose logs available',
                                  ),
                                ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/log-history');
                          },
                          child: const Text("See All Logs"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  } // getTooltipColor: (touchedSpot) =>

  Widget buildTimelineGlucoseGraph(double screenWidth) {
    if (fullGlucoseGraphData.isEmpty) {
      return const Center(child: Text("No glucose timeline data available."));
    }

    final double graphHeight = 420;
    final pointSpacing = screenWidth < 400 ? 45.0 : 60.0;
    final double graphWidth =
        (fullGlucoseGraphData.length * pointSpacing).clamp(screenWidth, 2400);
    final double maxY =
        fullGlucoseGraphData.map((e) => e.y).reduce((a, b) => a > b ? a : b) +
            20;

    final Map<double, DateTime> xDateMap = {
      for (int i = 0; i < fullGlucoseLogs.length; i++)
        i.toDouble(): DateTime.parse(fullGlucoseLogs[i]['date']),
    };

    final List<double> unwellXPositions = xDateMap.entries
        .where((entry) =>
            unwellDays.contains(DateFormat('yyyy-MM-dd').format(entry.value)))
        .map((entry) => entry.key)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 24),
        const Text(
          "Glucose Over Time (Avg. per Day)",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
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
              width: graphWidth,
              height: graphHeight,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: fullGlucoseGraphData.length.toDouble() - 1,
                  minY: 0,
                  maxY: maxY,
                  clipData: FlClipData.none(),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  titlesData: FlTitlesData(
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24, // 👈 adds space at the top
                        getTitlesWidget: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          "Date",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      axisNameSize: 30,
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final date = xDateMap[value];
                          if (date == null) return const SizedBox.shrink();
                          return SideTitleWidget(
                            meta: meta,
                            space: 10,
                            child: Transform.rotate(
                              angle: -0.6,
                              alignment: Alignment.topLeft,
                              child: Text(
                                DateFormat('dd/MM').format(date),
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: Text(
                        'Glucose ($measurementUnit)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      axisNameSize: 32,
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: 20,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: fullGlucoseGraphData,
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.orange.withAlpha(80),
                      ),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(
                    verticalLines: unwellXPositions.map((x) {
                      return VerticalLine(
                        x: x,
                        color: Colors.purple.withOpacity(0.6),
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
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => Colors.black.withAlpha(150),
                      tooltipRoundedRadius: 8,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final date = xDateMap[spot.x];
                          final dateKey = date != null
                              ? DateFormat('yyyy-MM-dd').format(date)
                              : '';
                          final logsForDay = glucoseLogs.where((log) {
                            return DateFormat('yyyy-MM-dd')
                                    .format(DateTime.parse(log['timestamp'])) ==
                                dateKey;
                          }).toList();

                          final logDetails = logsForDay.map((log) {
                            final time = DateFormat('HH:mm')
                                .format(DateTime.parse(log['timestamp']));
                            final value = double.tryParse(
                                    log['glucose_level'].toString()) ??
                                0.0;
                            return "🕒 $time - ${value.toStringAsFixed(1)} $measurementUnit";
                          }).join('\n');

                          final avg = logsForDay.isNotEmpty
                              ? (logsForDay
                                          .map((l) =>
                                              double.tryParse(l['glucose_level']
                                                  .toString()) ??
                                              0.0)
                                          .reduce((a, b) => a + b) /
                                      logsForDay.length)
                                  .toStringAsFixed(1)
                              : '-';

                          return LineTooltipItem(
                            "${DateFormat('dd MMM').format(date!)}\n\n$logDetails\n\nAvg: $avg $measurementUnit",
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList();
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

  Widget buildPredictionCard(double screenWidth) {
    const double spikeThresholdMg = 180;
    const double lowThresholdMg = 70;
    const double spikeThresholdMmol = 10.0;
    const double lowThresholdMmol = 3.9;

    final double highThreshold =
        measurementUnit == "mmol/L" ? spikeThresholdMmol : spikeThresholdMg;
    final double lowThreshold =
        measurementUnit == "mmol/L" ? lowThresholdMmol : lowThresholdMg;

    bool isSpike(double value) => value > highThreshold;
    bool isLow(double value) => value < lowThreshold;

    if (predictionError != null) {
      return _buildCardContainer(
        screenWidth,
        child: Text(
          predictionError!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (glucosePredictions.isEmpty) {
      return _buildCardContainer(
        screenWidth,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return _buildCardContainer(
      screenWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPredictionSpikeLikely())
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Predicted spike detected in the next few hours. Review your insulin or meal plans.",
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          Center(
            child: Text(
              "🔮 Glucose Predictions",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...glucosePredictions.map((prediction) {
            final dateTime = DateTime.parse(prediction['ds']);
            final formattedTime = DateFormat('HH:mm').format(dateTime);

            double yhat = double.tryParse(prediction['yhat'].toString()) ?? 0;
            double yhatLower =
                double.tryParse(prediction['yhat_lower'].toString()) ?? 0;
            double yhatUpper =
                double.tryParse(prediction['yhat_upper'].toString()) ?? 0;

            // Convert to mmol if needed
            if (measurementUnit == 'mmol/L') {
              yhat /= 18.01559;
              yhatLower /= 18.01559;
              yhatUpper /= 18.01559;
            }

            final bool spiking = isSpike(yhat);
            final bool low = isLow(yhat);

            Color backgroundColor;
            Color borderColor;

            if (low) {
              backgroundColor = Colors.orange.shade50;
              borderColor = Colors.orange.shade300;
            } else if (spiking) {
              backgroundColor = Colors.red.shade50;
              borderColor = Colors.red.shade300;
            } else {
              backgroundColor = Colors.grey.shade100;
              borderColor = Colors.grey.shade300;
            }

            return Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
              margin: const EdgeInsets.only(bottom: 8.0),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formattedTime,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${yhat.toStringAsFixed(1)} $measurementUnit",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: spiking
                              ? Colors.red[700]
                              : low
                                  ? Colors.orange[700]
                                  : Colors.black,
                        ),
                      ),
                      Text(
                        "Range: ${yhatLower.toStringAsFixed(1)} - ${yhatUpper.toStringAsFixed(1)}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (spiking || low)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            spiking
                                ? isInsulinDependent
                                    ? "⚠️ Spike — consider adjusting insulin"
                                    : "⚠️ Spike — monitor closely"
                                : "⚠️ Low — consider eating or resting",
                            style: TextStyle(
                              color: spiking ? Colors.red : Colors.orange[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCardContainer(double width, {required Widget child}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16.0),
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
      child: child,
    );
  }
}

// Widget to display circular data points with click functionality
class CircleDisplay extends StatelessWidget {
  final double? value;
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color color;
  final String measurementUnit;
  final String? formattedValue; // New parameter for formatted value

  const CircleDisplay(
      {super.key,
      this.value,
      required this.label,
      this.onTap,
      this.icon,
      required this.color,
      required this.measurementUnit,
      this.formattedValue});

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
              color: color, // Set the color dynamically
            ),
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 40, color: Colors.white)
                  : Text(
                      formattedValue ??
                          value.toString(), // Use formatted value if provided
                      style: TextStyle(
                        fontSize: 24,
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
