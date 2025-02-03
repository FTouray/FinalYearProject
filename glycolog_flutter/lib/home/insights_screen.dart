import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({Key? key}) : super(key: key);

  @override
  _InsightsScreenState createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  Map<String, dynamic>? insightsData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchInsights();
  }

  Future<void> fetchInsights() async {
    String? token = await AuthService().getAccessToken();

    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.14:8000/api/insights/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          insightsData = data; // Use the already decoded JSON
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to fetch insights: ${response.statusCode}')),
        );
      }
    } catch (error) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        backgroundColor: Colors.blue[800],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : insightsData == null
              ? const Center(child: Text('No insights available.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Personalized Insights',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      _buildPersonalizedInsights(),
                      const Divider(),
                      const Text(
                        'General Trends',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      _buildGeneralTrends(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPersonalizedInsights() {
    final personalInsights = insightsData?['personal_insights'];
    if (personalInsights == null) {
      return const Text('No personalized insights available.');
    }
    return Column(
      children: [
        _buildInsightCard(
          'You had high glucose levels in ${personalInsights['high_glucose']} sessions.',
          Icons.warning,
          Colors.red,
        ),
        _buildInsightCard(
          'You had less than 6 hours of sleep in ${personalInsights['low_sleep']} sessions.',
          Icons.bed,
          Colors.blue,
        ),
        _buildInsightCard(
          'Exercise made you feel energized in ${personalInsights['exercise_impact']} sessions.',
          Icons.fitness_center,
          Colors.green,
        ),
        _buildInsightCard(
          'You skipped meals in ${personalInsights['skipped_meals']} sessions.',
          Icons.fastfood,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildGeneralTrends() {
    final generalTrends = insightsData?['general_trends'];
    if (generalTrends == null) {
      return const Text('No general trends available.');
    }
    return Column(
      children: [
        const Text(
          'Average Glucose Levels',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          'Average glucose: ${generalTrends['avg_glucose']['avg_glucose']?.toStringAsFixed(1) ?? 'N/A'} mg/dL',
        ),
        const SizedBox(height: 20),
        const Text(
          'Average Sleep Hours',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          'Average sleep: ${generalTrends['avg_sleep']['avg_sleep']?.toStringAsFixed(1) ?? 'N/A'} hours',
        ),
        const SizedBox(height: 20),
        const Text(
          'Impact of Exercise on Wellness',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          'Sessions where exercise made people feel energized: ${generalTrends['exercise_effect'] ?? 'N/A'}',
        ),
        const SizedBox(height: 20),
        const Text(
          'Impact of Skipped Meals on Wellness',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          'Sessions where skipped meals negatively impacted wellness: ${generalTrends['skipped_meals_effect'] ?? 'N/A'}',
        ),
      ],
    );
  }

  Widget _buildInsightCard(String text, IconData icon, Color iconColor) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.2),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          text,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
