// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:Glycolog/services/auth_service.dart';
import 'package:Glycolog/services/google_fit_service.dart';
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
  Map<String, dynamic> _fitnessData = {};
  List<Map<String, String>> _recommendations = [];
  bool isGoogleFitConnected = false;
  bool isLoading = true;
  final GoogleFitService googleFitService = GoogleFitService();
  final String? apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => isLoading = true);
    await _fetchFitnessData();
    await _fetchRecommendations();
    setState(() => isLoading = false);
  }

  Future<void> _fetchFitnessData() async {
    final data = await googleFitService.fetchFitnessData();
    if (data != null) {
      setState(() {
        _fitnessData = data;
      });
    } else {
      _showErrorMessage('Failed to load fitness data');
    }
  }


  Future<void> _fetchRecommendations() async {
    String? token = await AuthService().getAccessToken();
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
                }));
      });
    } else {
      _showErrorMessage('Failed to load recommendations');
    }
  }

  void _connectGoogleFit() async {
    final googleFitService = GoogleFitService();
    bool isConnected = await googleFitService.signInWithGoogleFit();
    setState(() {
      isGoogleFitConnected = isConnected;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isConnected
            ? "Google Fit Connected!"
            : "Failed to connect Google Fit"),
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
                    onPressed: _connectGoogleFit,
                    child: const Text("Connect Google Fit"),
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

  Widget _buildFitnessDataCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryItem("Steps", _fitnessData['steps']),
            _buildSummaryItem(
                "Calories Burned", _fitnessData['calories_burned']),
            _buildSummaryItem("Distance", _fitnessData['distance_meters']),
            _buildSummaryItem("Sleep Hours", _fitnessData['sleep_hours']),
            _buildSummaryItem(
                "Avg Heart Rate", _fitnessData['average_heart_rate']),
            _buildSummaryItem("Latest Glucose Level",
                "${_fitnessData['latest_glucose_level']} ${_fitnessData['glucose_unit']}"),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, dynamic value) {
    return Text("$label: ${value ?? 'N/A'}");
  }
}
