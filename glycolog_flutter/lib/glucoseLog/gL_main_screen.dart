import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Importing the chart package
import 'package:http/http.dart' as http; // For making API requests
import 'package:intl/intl.dart';
import 'dart:convert'; // For JSON handling
import 'package:shared_preferences/shared_preferences.dart'; // For retrieving user settings
import '../home/base_screen.dart'; // Import BaseScreen
import 'package:Glycolog/utils.dart';

class GlucoseLogScreen extends StatefulWidget {
  const GlucoseLogScreen({super.key});

  @override
  _GlucoseLogScreenState createState() => _GlucoseLogScreenState();
}

class _GlucoseLogScreenState extends State<GlucoseLogScreen> {
  double? lastLog; // Changed to nullable double for safety
  double? averageLog; // Changed to nullable double for safety
  List<Map<String, dynamic>> glucoseLogs =
      []; // List to hold the full glucose log data
  String measurementUnit = 'mg/dL'; // Default measurement unit
  bool isLoading = true; // To show loading indicator while fetching data
  String? errorMessage; // To hold error messages if any
  List<FlSpot> graphData = []; // Define graphData variable

  @override
  void initState() {
    super.initState();
    _loadUserSettings(); // Load user settings to get the preferred measurement unit
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchGlucoseLogs(); // Fetch the glucose logs when the screen is displayed
  }

  // Fetch user's preferred measurement unit
  Future<void> _loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      measurementUnit =
          prefs.getString('selectedUnit') ?? 'mg/dL'; // Default to mg/dL
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

    if (token != null) {
      try {
        final response = await http.get(
          Uri.parse('http://192.168.1.14:8000/api/glucose-log/'), // Physical Device
        // Uri.parse('http://147.252.148.38:8000/api/glucose-log/'),
        // Uri.parse('http://172.20.10.3:8000/api/glucose-log/'), // Hotspot
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
        belowBarData:
            BarAreaData(show: true, color: Colors.blue.withOpacity(0.3)),
        showingIndicators: List.generate(spots.length, (index) => index),
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width; // Get the screen width

    return BaseScreen(
        selectedIndex: 1,
        onItemTapped: (index) {
          // Handle tab changes if needed
        },
        body: isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                // Wrap the entire content in SingleChildScrollView
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Error message display
                      if (errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            errorMessage!,
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      // Glucose Log Overview container
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        width: screenWidth, // Make it full width
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.0),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 8,
                              color: Colors.grey.shade300,
                              spreadRadius: 3,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Title for Glucose Log Section
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
                                // Last Log Circle
                                CircleDisplay(
                                  value: lastLog ?? 0.0,
                                  label: "Last Log",
                                  color: getPointColor(lastLog ?? 0.0),
                                  measurementUnit: measurementUnit,
                                  formattedValue: formatGlucoseValue(lastLog, measurementUnit), // Use formatted value
                                ),
                                // Add Log Circle
                                CircleDisplay(
                                  value: null,
                                  label: "Add Log",
                                  color: Colors.blue[300]!,
                                  measurementUnit: measurementUnit,
                                  onTap: () {
                                    Navigator.pushNamed(context, '/add-log');
                                  },
                                  icon: Icons.add,
                                ),
                                CircleDisplay(
                                  value: averageLog ?? 0.0,
                                  label: "Average",
                                  color: getPointColor(averageLog ?? 0.0),
                                  measurementUnit: measurementUnit,
                                  formattedValue: formatGlucoseValue(averageLog, measurementUnit), // Use formatted value
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Graph Section with fixed-size container and scrollable content
                      // Graph Section with dynamic height
                      AspectRatio(
                        aspectRatio: 1,
                        child:
                      Container(
                        width: screenWidth, // Full width of the screen
                        //height: 400, // Fixed height for the graph
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.0),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 8,
                              color: Colors.grey.shade300,
                              spreadRadius: 3,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Container(
                            width: screenWidth *
                                2, // Ensure the graph spans the full width
                            padding: const EdgeInsets.all(16.0),

                            child: LineChart(
                              LineChartData(
                                gridData:
                                    FlGridData(show: true), // Permanent grid
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border.all(color: Colors.grey),
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    axisNameWidget: Text(
                                        'Glucose Level ($measurementUnit)'),
                                    axisNameSize: 30,
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval:
                                          getMaxY() / 5, // Y-axis intervals
                                      getTitlesWidget: (value, meta) {
                                        return Text('${value.toInt()}');
                                      },
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    axisNameWidget: Text('Time (24h)'),
                                    axisNameSize: screenWidth / 20, //30'
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval:
                                          2, // Show every 2 hours on x-axis
                                      getTitlesWidget: (value, meta) {
                                        final hour = value.toInt();
                                        return SideTitleWidget(
                                          axisSide: meta.axisSide,
                                          child: Transform.translate(
                                            offset: Offset(-10,
                                                5), // Adjust for better spacing
                                            child: Transform.rotate(
                                              angle: -45 *
                                                  3.1416 /
                                                  180, // Rotate the text 45 degrees
                                              child: Text(
                                                hour < 10
                                                    ? '0$hour:00'
                                                    : '$hour:00', // Format time labels
                                                style: const TextStyle(
                                                    fontSize: 12),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  rightTitles: AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  topTitles: AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                ),
                                minX: 0,
                                maxX:
                                    24, // X-axis goes from 0 to 24 (representing hours)
                                minY: 0,
                                maxY: getMaxY(), // Y-axis adjusts dynamically
                                lineBarsData: getLineChartBarData(),
                                lineTouchData: LineTouchData(
                                  // Line touch data should be here
                                  touchTooltipData: LineTouchTooltipData(
                                    tooltipRoundedRadius:
                                        8, // Rounded corner radius for the tooltip
                                    tooltipPadding: const EdgeInsets.all(
                                        8), // Padding inside the tooltip
                                    tooltipMargin:
                                        10, // Space between the tooltip and the touch point
                                    fitInsideHorizontally:
                                        true, // Keeps tooltip within chart boundaries horizontally
                                    fitInsideVertically:
                                        true, // Ensures the tooltip fits inside the chart
                                    getTooltipItems: (touchedSpots) {
                                      return touchedSpots.map((spot) {
                                       final log = glucoseLogs.firstWhere(
                                            (log) =>
                                                DateTime.parse(log['timestamp'])
                                                        .hour ==
                                                    spot.x.toInt() &&
                                                DateTime.parse(log['timestamp'])
                                                        .minute ==
                                                    ((spot.x - spot.x.toInt()) *
                                                            60)
                                                        .toInt(),
                                            orElse: () => {});
                                        final dateTime = DateTime.parse(log['timestamp']);
                                        final formattedTime =
                                            DateFormat('HH:mm')
                                                .format(dateTime);
                                        return LineTooltipItem(
                                          'Glucose: ${spot.y.toStringAsFixed(1)}\nTime: $formattedTime',
                                          const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
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
                      // Recent Glucose Log History Section
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
                              offset: Offset(0, 4),
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
                                      itemCount: glucoseLogs.length > 5 ? 5 : glucoseLogs.length,
                                      itemBuilder: (context, index) {
                                        final log = glucoseLogs[index];
                                        return ListTile(
                                          title: Text('Glucose Level: ${log['glucose_level']?.toStringAsFixed(measurementUnit == 'mg/dL' ? 0 : 1) ?? 'N/A'} $measurementUnit'),
                                          subtitle: Text('Date & Time: ${formatTimestamp(log['timestamp'])}'),
                                        );
                                      },
                                    )
                                  : Center(
                                      child: Text('No recent glucose logs available')),
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
              ));
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
                      formattedValue ?? value.toString(), // Use formatted value if provided
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
