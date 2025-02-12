import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({Key? key}) : super(key: key);

  @override
  _InsightsScreenState createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  Map<String, dynamic>? insightsData;
  bool isLoading = true;
  final String? apiUrl = dotenv.env['API_URL']; 

  @override
  void initState() {
    super.initState();
    fetchAIInsights();
  }

  Future<void> fetchAIInsights() async {
    String? token = await AuthService().getAccessToken();

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/ai-insights/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          insightsData = data;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to fetch AI insights: ${response.statusCode}')),
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
        title: const Text('AI-Powered Insights'),
        backgroundColor: Colors.blue[800],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : insightsData == null
              ? const Center(child: Text('No AI insights available.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Personalized AI Insights',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      _buildWellnessPredictions(),
                      const Divider(),
                      _buildGlucosePredictions(),
                      const Divider(),
                      _buildIdentifiedPatterns(),
                      const Divider(),
                      const Text(
                        'General Trends & Community Insights',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      _buildGeneralTrends(),
                      const Divider(),
                      const Text(
                        'AI Personalized Recommendations',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      _buildRecommendations(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildWellnessPredictions() {
    final wellnessPredictions = insightsData?['wellness_predictions'];
    if (wellnessPredictions == null || wellnessPredictions.isEmpty) {
      return const Text('No wellness predictions available.');
    }
    return Column(
      children: [
        _buildInsightCard(
          'Predicted wellness risk score: ${wellnessPredictions[0]['wellness_risk_score']}%',
          Icons.health_and_safety,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildGlucosePredictions() {
    final glucosePredictions = insightsData?['glucose_predictions'];
    if (glucosePredictions == null || glucosePredictions.isEmpty) {
      return const Text('No glucose predictions available.');
    }
    return Column(
      children: glucosePredictions.map<Widget>((glucose) {
        return _buildInsightCard(
          'Predicted glucose level: ${glucose['predicted_glucose']} mg/dL (Confidence: ${glucose['confidence']}%)',
          Icons.bloodtype,
          Colors.red,
        );
      }).toList(),
    );
  }

  Widget _buildIdentifiedPatterns() {
    final patterns = insightsData?['patterns'];
    if (patterns == null || patterns.isEmpty) {
      return const Text('No specific patterns detected.');
    }
    return Column(
      children: patterns.map<Widget>((pattern) {
        return _buildInsightCard(
          pattern,
          Icons.trending_up,
          Colors.orange,
        );
      }).toList(),
    );
  }

  Widget _buildGeneralTrends() {
    final generalTrends = insightsData?['general_trends'];
    if (generalTrends == null || generalTrends.isEmpty) {
      return const Text('No general trends available.');
    }
    return Column(
      children: generalTrends.map<Widget>((trend) {
        return _buildInsightCard(
          trend,
          Icons.people,
          Colors.purple,
        );
      }).toList(),
    );
  }

  Widget _buildRecommendations() {
    final recommendations = insightsData?['recommendations'];
    if (recommendations == null || recommendations.isEmpty) {
      return const Text('No recommendations available.');
    }
    return Column(
      children: recommendations.map<Widget>((rec) {
        return _buildInsightCard(
          rec,
          Icons.lightbulb,
          Colors.blue,
        );
      }).toList(),
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
