import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Importing the chart package
import 'package:http/http.dart' as http; // For making API requests
import 'dart:convert'; // For JSON handling
import 'package:shared_preferences/shared_preferences.dart'; // For retrieving user settings
import '../home/base_screen.dart'; // Import BaseScreen

class GlucoseLogScreen extends StatefulWidget {
  const GlucoseLogScreen({super.key});

  @override
  _GlucoseLogScreenState createState() => _GlucoseLogScreenState();
}

class _GlucoseLogScreenState extends State<GlucoseLogScreen> {
  double lastLog = 0.0; // Default value for last glucose log
  double averageLog = 0.0; // Default value for average glucose log
  List<Map<String, dynamic>> glucoseLogs = []; // List to hold the full glucose log data
  String measurementUnit = 'mg/dL'; // Default measurement unit
  bool isLoading = true; // To show loading indicator while fetching data
  String? errorMessage; // To hold error messages if any

  @override
  void initState() {
    super.initState();
    _loadUserSettings(); // Load user settings to get the preferred measurement unit
    //fetchGlucoseLogs(); // Fetch the glucose logs when the screen initializes
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
      measurementUnit = prefs.getString('selectedUnit') ?? 'mg/dL'; // Default to mg/dL
    });
  }

  // Conversion function to convert mg/dL to mmol/L if necessary
  double convertToMmolL(double value) {
    return value / 18.01559; // Convert mg/dL to mmol/L
  }

  // Fetch glucose logs from the server using the refreshed token if needed
  Future<void> fetchGlucoseLogs() async {
    String? token = await AuthService().getAccessToken(); // Get access token or refresh if expired

    if (token != null) {
      try {
        final response = await http.get(
         // Uri.parse('http://10.0.2.2:8000/api/glucose-log/'), //For Emulator
          Uri.parse('http://192.168.1.19:8000/api/glucose-log/'),  // For Physical Device 
          headers: {
            'Authorization': 'Bearer $token', // Send token in request header
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          setState(() {
            lastLog = data['lastLog'] ?? 0.0; // Get the last log or set to 0
            averageLog = data['averageLog'] ?? 0.0; // Get the average log or set to 0
            glucoseLogs = List<Map<String, dynamic>>.from(data['logs'] ?? []); // Get logs or an empty list

            // Apply unit conversion to each glucose log based on the user's setting
            if (measurementUnit == 'mmol/L') {
              lastLog = convertToMmolL(lastLog);
              averageLog = convertToMmolL(averageLog);
              for (var log in glucoseLogs) {
                log['glucoseLevel'] = convertToMmolL(log['glucoseLevel']);
              }
            }

            isLoading = false; // Data has been loaded
          });
        } else {
          // Handle the case where the server returns an error
          setState(() {
            errorMessage = 'Log Glucose Levels.';
            isLoading = false; // Stop loading
          });
        }
      } catch (e) {
        // Handle exceptions (e.g., network errors)
        setState(() {
          errorMessage = 'An error occurred: $e'; // Show the error
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

  // Function to determine circle color based on glucose levels
  Color getCircleColor(double? value) {
    if (value == null) return Colors.blue[300]!;
    if (value < (measurementUnit == 'mg/dL' ? 80 : 4.4)) {
      return Colors.green; // Low glucose levels
    } else if (value > (measurementUnit == 'mg/dL' ? 180 : 10.0)) {
      return Colors.red; // High glucose levels
    }
    return Colors.blue[800]!; // Normal glucose levels
  }

  // Function to dynamically determine the graph line color based on glucose level
  Color getGraphLineColor(double glucoseLevel) {
    if (glucoseLevel < (measurementUnit == 'mg/dL' ? 80 : 4.4)) {
      return Colors.green; // Low glucose levels
    } else if (glucoseLevel > (measurementUnit == 'mg/dL' ? 180 : 10.0)) {
      return Colors.red; // High glucose levels
    }
    return Colors.blue; // Normal glucose levels
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      selectedIndex: 1, // Assuming glucose log is the second tab
      onItemTapped: (index) {
        // Handle tab changes if needed
      },
      body: isLoading
          ? Center(child: CircularProgressIndicator()) // Show loading indicator while fetching data
          : Padding(
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
                  // Elevated Rectangle with Circles
                  Container(
                    padding: const EdgeInsets.all(16.0),
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
                        // Circles in Elevated Rectangle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Last Log Circle
                            CircleDisplay(
                              value: lastLog,
                              label: "Last Log",
                              color: getCircleColor(lastLog),
                              onTap: () {
                                // Maybe display detail of last log.
                              },
                            ),
                            // Add Log Circle
                            CircleDisplay(
                              value: null,
                              label: "Add Log",
                              color: Colors.blue[300]!,
                              onTap: () {
                                Navigator.pushNamed(context, '/add-log');
                              },
                              icon: Icons.add,
                            ),
                            // Average Log Circle
                            CircleDisplay(
                              value: averageLog,
                              label: "Average",
                              color: getCircleColor(averageLog),
                              
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Graph Section
                  Expanded(
                    child: glucoseLogs.isNotEmpty // Check if glucoseLogs has data
                        ? Column(
                            children: [
                              // Graph
                              Expanded(
                                flex: 3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        blurRadius: 8,
                                        color: Colors.grey.shade300,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Glucose Levels Today",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[800],
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Expanded(
                                        child: LineChart(
                                          LineChartData(
                                            gridData: FlGridData(show: true),
                                            borderData: FlBorderData(show: false),
                                            titlesData: FlTitlesData(
                                              bottomTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 22,
                                                  getTitlesWidget: (value, meta) {
                                                    return Text(
                                                        '${value.toInt()}'); // X-axis labels (glucose levels)
                                                  },
                                                ),
                                              ),
                                              leftTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 40,
                                                  getTitlesWidget: (value, meta) {
                                                    return Text(
                                                        '${value.toInt()}'); // Y-axis labels (time)
                                                  },
                                                ),
                                              ),
                                            ),
                                            lineBarsData: [
                                              LineChartBarData(
                                                spots: glucoseLogs
                                                    .asMap()
                                                    .entries
                                                    .map((e) => FlSpot(
                                                        e.key.toDouble(),
                                                        e.value['glucoseLevel']))
                                                    .toList(),
                                                isCurved: true,
                                                color: Colors.blue, // Use a single color for now
                                                barWidth: 3,
                                                belowBarData: BarAreaData(
                                                    show: true,
                                                    color: Colors.blue.withOpacity(0.3)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Log History
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Recent Logs",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: glucoseLogs.length > 5 ? 5 : glucoseLogs.length,
                                        itemBuilder: (context, index) {
                                          final log = glucoseLogs[index];
                                          return ListTile(
                                            title: Text(
                                                'Glucose Level: ${log['glucoseLevel']} $measurementUnit'),
                                            subtitle: Text('Date: ${log['timestamp']}'),
                                            onTap: () {
                                              // No navigation to log-details page, just show the history here.
                                              // Can be expanded to show more details here itself.
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                    // "See All" Button
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
                          )
                        : Center(
                            child: Text(
                                "Log Glucose Levels For Data To Be Displayed."), // Display message when no data
                          ),
                  ),
                ],
              ),
            ),
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

  const CircleDisplay({super.key, this.value, required this.label, this.onTap, this.icon, required this.color});

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
                      value != null ? value.toString() : "0",
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
