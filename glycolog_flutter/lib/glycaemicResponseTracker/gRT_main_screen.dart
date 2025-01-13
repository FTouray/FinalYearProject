// ignore_for_file: avoid_print

import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:Glycolog/home/base_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Glycolog/utils.dart';

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
  String measurementUnit = 'mg/dL'; // Default measurement unit

  @override
  void initState() {
    super.initState();
    _loadUserSettings(); // Load user settings to get the preferred measurement unit
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchGlycaemicData(); 
    // _fetchInsights();
  }

  Future<void> _fetchGlycaemicData() async {
    String? token = await AuthService().getAccessToken();
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.12:8000/api/glycaemic-response-main'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          lastResponse = (data['lastResponse'] as num?)?.toInt() ?? 0;
          avgResponse = (data['avgResponse'] as num?)?.toInt() ?? 0;
          dailyGoalProgress = (data['dailyGoalProgress'] as num?)?.toDouble() ?? 0.0;
          mealInsight = data['mealInsight'] ?? "No insights available";
          allMealLogs = data['all_meal_logs'] ?? [];
          isLoading = false;
        });
        print('Fetched allMealLogs: $allMealLogs');
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

   // Fetch user's preferred measurement unit
  Future<void> _loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      measurementUnit =
          prefs.getString('selectedUnit') ?? 'mg/dL'; // Default to mg/dL
    });
  }

  // Conversion function to convert mg/dL to mmol/L if necessary
  double convertToMmolL(double value) {
    return value / 18.01559; // Convert mg/dL to mmol/L
  }

  // Function to format the glucose values based on the unit
  String formatGlucoseValue(double? value) {
    if (value == null) return '-'; // Return a placeholder if the value is null
    if (measurementUnit == 'mmol/L') {
      return value.toStringAsFixed(1); // One decimal point for mmol/L
    } else {
      return value.round().toString(); // Nearest whole number for mg/dL
    }
  }

 Future<void> _fetchInsights() async {
    String? token = await AuthService().getAccessToken();
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.19:8000/api/glycaemic-response-analysis'), // Physical Device
        // Uri.parse('http://172.20.10.3:8000/api/glycaemic-response-analysis/'), // Hotspot
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          insights = data['insights'].map((insight) {
            double avgGlucose = insight['avg_glucose_level'];
            if (measurementUnit == 'mmol/L') {
              convertToMmolL(avgGlucose);
            }
            return {
              ...insight,
              'avg_glucose_level': avgGlucose.toStringAsFixed(1),
              'glucose_unit': measurementUnit,
            };
          }).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load insights';
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


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return BaseScreen(
      selectedIndex: 1,
      onItemTapped: (index) {},
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  // GRT Overview container
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
                          offset: Offset(0, 4),
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
                            // Last Response Circle
                            CircleDisplay(
                              value: lastResponse ?? 0,
                              label: "Last Meal GI",
                              color: Colors.blue[300]!,
                            ),
                            // Add New Log Circle
                            CircleDisplay(
                              label: "Add Meal",
                              color: Colors.blue[300]!,
                              icon: Icons.add,
                              onTap: () {
                                Navigator.pushNamed(context, '/log-meal');
                              },
                            ),
                            // Average Response Circle
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
                  const SizedBox(height: 30),

                  // Recent Meal Log History Section
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
                                      title: Text('Meal ID: ${meal['user_meal_id']}${meal['name'] != null ? ' - ${meal['name']}' : ''}'),
                                      subtitle: Text('Timestamp: ${formatTimestamp(meal['timestamp'])}'),
                                    );
                                  },
                                )
                              : Center(
                                  child: Text('No recent meal logs available')),
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

                  // Analysis Insights Section
                  // Container(
                  //   width: screenWidth,
                  //   decoration: BoxDecoration(
                  //     color: Colors.white,
                  //     borderRadius: BorderRadius.circular(16.0),
                  //     boxShadow: [
                  //       BoxShadow(
                  //         blurRadius: 8,
                  //         color: Colors.grey.shade300,
                  //         spreadRadius: 3,
                  //         offset: Offset(0, 4),
                  //       ),
                  //     ],
                  //   ),
                  //   padding: const EdgeInsets.all(16.0),
                  //   child: Column(
                  //     children: [
                  //       Text(
                  //         "Glycaemic Response Analysis",
                  //         style: TextStyle(
                  //           fontSize: 18,
                  //           fontWeight: FontWeight.bold,
                  //           color: Colors.blue[800],
                  //         ),
                  //       ),
                  //       const SizedBox(height: 10),
                  //       insights.isNotEmpty
                  //           ? Column(
                  //               children: insights.map((insight) {
                  //                 return Card(
                  //                   margin: const EdgeInsets.symmetric(
                  //                       vertical: 10),
                  //                   child: Padding(
                  //                     padding: const EdgeInsets.all(16.0),
                  //                     child: Column(
                  //                       crossAxisAlignment:
                  //                           CrossAxisAlignment.start,
                  //                       children: [
                  //                         Text(
                  //                           "Meal ID: ${insight['meal_id']}",
                  //                           style: TextStyle(
                  //                               fontSize: 18,
                  //                               fontWeight: FontWeight.bold),
                  //                         ),
                  //                         const SizedBox(height: 10),
                  //                         Text(
                  //                             "Timestamp: ${insight['meal_timestamp']}"),
                  //                         const SizedBox(height: 10),
                  //                         Text(
                  //                             "Average Glucose Level: ${insight['avg_glucose_level']}"),
                  //                         const SizedBox(height: 10),
                  //                         Text(
                  //                             "Total Glycaemic Index: ${insight['total_glycaemic_index']}"),
                  //                         const SizedBox(height: 10),
                  //                         Text(
                  //                             "Total Carbs: ${insight['total_carbs']}"),
                  //                         const SizedBox(height: 10),
                  //                         Text("Food Items:"),
                  //                         ...insight['food_items']
                  //                             .map<Widget>((item) {
                  //                           return Text(
                  //                             "- ${item['name']}: GI ${item['glycaemic_index']}, Carbs ${item['carbs']}g",
                  //                           );
                  //                         }).toList(),
                  //                         const SizedBox(height: 10),
                  //                         Text(
                  //                           "Recommendation: ${insight['recommendation']}",
                  //                           style: TextStyle(
                  //                               fontSize: 16,
                  //                               fontWeight: FontWeight.bold,
                  //                               color: Colors.green),
                  //                         ),
                  //                       ],
                  //                     ),
                  //                   ),
                  //                 );
                  //               }).toList(),
                  //             )
                  //           : Center(child: Text("No insights available")),
                  //     ],
                  //   ),
                  // ),
                  // const SizedBox(height: 30),

                  // Feedback Section
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
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Post-Meal Feedback",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/grt-feedback');
                          },
                          child: const Text("Log Feedback"),
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
