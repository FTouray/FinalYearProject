// ignore_for_file: avoid_print

import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:Glycolog/home/base_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  List<dynamic> mealLogHistory = [];
  List<dynamic> allMealLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchGlycemicData();
  }

  Future<void> _fetchGlycemicData() async {
    String? token = await AuthService().getAccessToken();
    try {
      final response = await http.get(
        Uri.parse(
            'http://192.168.1.19:8000/api/glycaemic-response-main'), 
        headers: {
          'Authorization': 'Bearer $token', 
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          lastResponse =
              (data['lastResponse'] as num?)?.toInt() ?? 0; // Convert to int
          avgResponse =
              (data['avgResponse'] as num?)?.toInt() ?? 0; // Convert to int
          dailyGoalProgress =
              (data['dailyGoalProgress'] as num?)?.toDouble() ?? 0.0;
          mealInsight = data['mealInsight'] ?? "No insights available";
          mealLogHistory = data['mealLogHistory'] ?? [];
          allMealLogs = data['allMealLogs'] ?? [];
          isLoading = false;
        });
        print('Fetched allMealLogs: $allMealLogs and Fetched mealLogHistory: $mealLogHistory');
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
                                  itemCount: allMealLogs.length,
                                  itemBuilder: (context, index) {
                                    final meal = allMealLogs[index];
                                    return ListTile(
                                      title: Text(meal['name']),
                                      subtitle: Text(meal['timestamp']),
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

                  // Daily Goals and Insights Section
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
                          "Daily Goals & Insights",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text("Goal Progress:"),
                            CircularProgressIndicator(
                              value: dailyGoalProgress,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation(Colors.blue),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Meal Insights:\n$mealInsight",
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

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
