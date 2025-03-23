// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:Glycolog/services/auth_service.dart';
import 'package:Glycolog/services/health_connect_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VirtualHealthCoachScreen extends StatefulWidget {
  const VirtualHealthCoachScreen({super.key});

  @override
  _VirtualHealthCoachScreenState createState() =>
      _VirtualHealthCoachScreenState();
}

class _VirtualHealthCoachScreenState extends State<VirtualHealthCoachScreen> {
  Map<String, dynamic> _fitnessData = {
    "steps": 0,
    "calories_burned": 0,
    "distance_meters": 0,
    "sleep_hours": 0.0,
    "average_heart_rate": "No data",
    "latest_glucose_level": "N/A",
    "glucose_unit": "mg/dL",
  };

  List<Map<String, String>> _recommendations = [];
  bool isHealthConnectConnected = false;
  bool isLoading = true;
  final String? apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => isLoading = true);

    final healthService = HealthConnectService();
    final token = await AuthService().getAccessToken();

    await healthService.requestPermissions();
    await healthService.sendToBackend(token!); // ✅ Sends data if available

    await _fetchVirtualHealthCoachSummary(token);
    setState(() => isLoading = false);
  }

  Future<void> _fetchVirtualHealthCoachSummary(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/virtual-health-coach/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _fitnessData = {
            "steps": data["latest_fitness_data"]["steps"],
            "calories_burned": data["latest_fitness_data"]["calories_burned"],
            "distance_meters": data["latest_fitness_data"]["distance_meters"],
            "sleep_hours": data["latest_fitness_data"]["sleep_hours"],
            "average_heart_rate": data["latest_fitness_data"]["heart_rate"],
            "latest_glucose_level": data["glucose_summary"],
            "glucose_unit": "mg/dL",
          };
          _recommendations = [
            {
              "timestamp": DateTime.now().toIso8601String(),
              "recommendation": data["recommendation"]
            }
          ];
        });
      } else {
        print("Error fetching virtual coach: ${response.body}");
      }
    } catch (e) {
      print("Error: $e");
    }
  }


  // Fetch Fitness Data & Send to Backend
  Future<void> _fetchFitnessData() async {
    final healthService = HealthConnectService();
    final token = await AuthService().getAccessToken();

    if (token == null) {
      _showErrorMessage("User not authenticated.");
      return;
    }

    try {
      final permissionGranted = await healthService.requestPermissions();
      if (!permissionGranted) {
        _showErrorMessage("Permission to access health data was denied.");
        return;
      }

      await healthService.sendToBackend(token);

      final data = await healthService.fetchHealthData();
      if (data.isNotEmpty) {
        setState(() {
          _fitnessData = data.last; // show the most recent workout
        });
      } else {
        _showErrorMessage("No workouts found in the last 24 hours.");
      }
    } catch (e) {
      print("Error: $e");
      _showErrorMessage("Failed to sync health data.");
    }
  }


  // Fetch AI Recommendations from Backend
  Future<void> _fetchRecommendations() async {
    final token = await AuthService().getAccessToken();

    if (token == null) {
      _showErrorMessage("User not authenticated.");
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/virtual-health-coach/recommendations/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _recommendations = List<Map<String, String>>.from(
            data['past_recommendations'].map((rec) => {
                  'timestamp': rec['generated_at'],
                  'recommendation': rec['recommendation']
                }),
          );
        });
      } else {
        _showErrorMessage('Failed to load recommendations');
      }
    } catch (e) {
      print("Error fetching recommendations: $e");
      _showErrorMessage('Failed to load recommendations');
    }
  }

  void _connectHealthConnect() async {
    final healthService = HealthConnectService();

    bool isConnected = await healthService.requestPermissions();

    setState(() {
      isHealthConnectConnected = isConnected;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isConnected
              ? "Health permissions granted via Google Fit!"
              : "Health permissions denied.",
        ),
        backgroundColor: isConnected ? Colors.green : Colors.red,
      ),
    );
  }


  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Virtual Health Coach'),
        backgroundColor: Colors.blue[800],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  ElevatedButton(
                    onPressed: _connectHealthConnect,
                    child: const Text("Connect to Health Connect"),
                  ),
                  ElevatedButton(
                    onPressed: _fetchFitnessData,
                    child: const Text("Sync Fitness Data"),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle("Your Fitness Data"),
                  _fitnessData.isEmpty
                      ? _buildEmptyState("No fitness data available.")
                      : _buildFitnessDataCard(),
                  const SizedBox(height: 20),
                  _buildSectionTitle("AI-Generated Recommendations"),
                  _recommendations.isEmpty
                      ? _buildEmptyState("No recommendations available.")
                      : Column(
                          children: _recommendations.map((rec) {
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              child: ListTile(
                                title: Text(rec['recommendation'] ?? ''),
                                subtitle: Text('Date: ${rec['timestamp']}'),
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/chatbot');
        },
        child: const Icon(Icons.chat),
        tooltip: 'Chat with AI Health Coach',
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildEmptyState(String message) {
    return Column(
      children: [
        const Icon(Icons.info_outline, size: 50, color: Colors.grey),
        const SizedBox(height: 10),
        Text(message, style: const TextStyle(fontSize: 16, color: Colors.grey)),
      ],
    );
  }

    Widget _buildSummaryItem(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Text(
            value?.toString() ?? 'N/A',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }

  Widget _buildFitnessDataCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _fitnessData.entries.map((entry) {
            return _buildSummaryItem(entry.key, entry.value);
          }).toList(),
        ),
      ),
    );
  }
}
