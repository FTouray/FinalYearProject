import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Importing the chart package
import 'package:http/http.dart' as http; // For making API requests
import 'package:intl/intl.dart';
import 'dart:convert'; // For JSON handling
import 'package:shared_preferences/shared_preferences.dart'; // For retrieving user settings
import '../home/base_screen.dart'; // Import BaseScreen

class GlucoseLogScreen extends StatefulWidget {
  const GlucoseLogScreen({super.key});

  @override
  _GlucoseLogScreenState createState() => _GlucoseLogScreenState();
}

class _GlucoseLogScreenState extends State<GlucoseLogScreen> {
  double? lastLog; // Changed to nullable double for safety
  double? averageLog; // Changed to nullable double for safety
  List<Map<String, dynamic>> glucoseLogs = []; // List to hold the full glucose log data
  String measurementUnit = 'mg/dL'; // Default measurement unit
  bool isLoading = true; // To show loading indicator while fetching data
  String? errorMessage; // To hold error messages if any

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
      measurementUnit = prefs.getString('selectedUnit') ?? 'mg/dL'; // Default to mg/dL
    });
  }

  // Conversion function to convert mg/dL to mmol/L if necessary
  double convertToMmolL(double value) {
    return value / 18.01559; // Convert mg/dL to mmol/L
  }

  // Safe parsing for double values, returns null if the value cannot be parsed
  double? parseDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  // Fetch glucose logs from the server using the refreshed token if needed
  Future<void> fetchGlucoseLogs() async {
    String? token = await AuthService().getAccessToken(); // Get access token or refresh if expired

    if (token != null) {
      try {
        final response = await http.get(
         // Uri.parse('http://10.0.2.2:8000/api/glucose-log/'), //For Emulator
         Uri.parse('http://192.168.1.19:8000/api/glucose-log/'),  // For Physical Device 
         // Uri.parse('http://147.252.148.38:8000/api/glucose-log/'), // For Eduroam API endpoint
         // Uri.parse('http://192.168.40.184:8000/api/glucose-log/'), // Ethernet IP
          headers: {
            'Authorization': 'Bearer $token', // Send token in request header
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          setState(() {
            // Ensure this data is being correctly set
            lastLog = parseDouble(data['lastLog']); 
            averageLog = parseDouble(data['averageLog']); 
            glucoseLogs = List<Map<String, dynamic>>.from(data['logs'] ?? []); 

            // Sort logs by timestamp to find the last log
            glucoseLogs.sort((a, b) => DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])));

            lastLog = glucoseLogs.isNotEmpty ? parseDouble(glucoseLogs.first['glucose_level']) : null;

            // Calculate the average log
            if (glucoseLogs.isNotEmpty) {
              double total = glucoseLogs.fold(0.0, (sum, log) => sum + (parseDouble(log['glucose_level']) ?? 0.0));
              averageLog = total / glucoseLogs.length;
            } else {
              averageLog = null;
            }
        

            // Apply unit conversion to each glucose log based on the user's setting
            if (measurementUnit == 'mmol/L') {
              lastLog = lastLog != null ? convertToMmolL(lastLog!) : null;
              averageLog = averageLog != null ? convertToMmolL(averageLog!) : null;
              for (var log in glucoseLogs) {
                log['glucose_level'] = log['glucose_level'] != null
                    ? convertToMmolL(parseDouble(log['glucose_level']) ?? 0.0)
                    : null; // Safely parse glucose level
              }
            }

             isLoading = false; // Data has been loaded
          });
        } else {
          // Handle the case where the server returns an error
          setState(() {
            errorMessage = 'Failed to load glucose logs.';
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

 // Determine the point color based on glucose level
  Color getPointColor(double glucoseLevel) {
    if (glucoseLevel < (measurementUnit == 'mg/dL' ? 80 : 4.4)) {
      return Colors.green; // Low
    } else if (glucoseLevel > (measurementUnit == 'mg/dL' ? 180 : 10.0)) {
      return Colors.red; // High
    }
    return Colors.blue; // Normal
  }

  // Function to get graph data points
  List<FlSpot> getGraphData() {
    return glucoseLogs.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value['glucose_level'] ?? 0.0))
        .toList();
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
        belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.3)),
      )
    ];
  }

@override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width; // Get the screen width

    return BaseScreen(
      selectedIndex: 1,
      onItemTapped: (index) {
        // Handle tab changes if needed
      },
      body: isLoading
          ? Center(child: CircularProgressIndicator())
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
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Graph Section with fixed-size container and scrollable content
                  Container(
                    width: screenWidth, // Full width of the screen
                    height: 250, // Fixed height to match the size of the Glucose Log Overview
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
                        width: screenWidth, // Ensure the graph spans the full width
                        padding: const EdgeInsets.all(16.0),
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true), // Permanent grid
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(color: Colors.grey),
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                axisNameWidget: Text('Glucose Level ($measurementUnit)'),
                                axisNameSize: 30, 
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: getMaxY() / 5, // Y-axis intervals
                                  getTitlesWidget: (value, meta) {
                                    return Text('${value.toInt()}');
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                axisNameWidget: Text('Time (24h)'),
                                axisNameSize: screenWidth / 20, //30
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  //interval: 6, // X-axis intervals (fixed time intervals)
                                   interval: 1, // X-axis intervals (hourly)
                                  getTitlesWidget: (value, meta) {
                                    // const times = ['00:00', '06:00', '12:00', '18:00', '24:00'];
                                    // return Text(times[value.toInt() % times.length]); // Static time labels
                                    return Text('${value.toInt()}:00'); // Display each hour
                                  },
                                ),
                              ),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            minX: 0,
                            maxX: 24, // X-axis goes from 0 to 24 (representing hours)
                            minY: 0,
                            maxY: getMaxY(), // Y-axis adjusts dynamically
                            lineBarsData: getLineChartBarData(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Log History
                  Expanded(
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
                                    'Glucose Level: ${log['glucose_level']?.toStringAsFixed(measurementUnit == 'mg/dL' ? 0 : 1) ?? 'N/A'} $measurementUnit'),
                                subtitle: Text('Date: ${log['timestamp']}'),
                              );
                            },
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

  const CircleDisplay({super.key, this.value, required this.label, this.onTap, this.icon, required this.color, required this.measurementUnit});

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