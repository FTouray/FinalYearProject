import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:Glycolog/services/auth_service.dart';
import 'package:Glycolog/services/google_fit_service.dart';
import 'package:Glycolog/virtualHealthCoach/chatbot_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VirtualHealthCoachScreen extends StatefulWidget {
  const VirtualHealthCoachScreen({super.key});

  @override
  _VirtualHealthCoachScreenState createState() =>
      _VirtualHealthCoachScreenState();
}

class _VirtualHealthCoachScreenState extends State<VirtualHealthCoachScreen> {
  Map<String, dynamic> _exerciseSummary = {};
  List<Map<String, String>> _recommendations = [];
  List<Map<String, String>> _pastRecommendations = [];
  Map<String, dynamic> _healthTrends = {};
  bool isGoogleFitConnected = false;
  bool isLoading = true;
  final String? apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => isLoading = true);
    await _fetchExerciseSummary();
    await _fetchRecommendations();
    await _fetchPastRecommendations();
    await _fetchHealthTrends("weekly");
    setState(() => isLoading = false);
  }

  Future<void> _fetchExerciseSummary() async {
    String? token = await AuthService().getAccessToken();
    final response = await http.get(
      Uri.parse('$apiUrl/virtual-health-coach/exercise-summary/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        _exerciseSummary = jsonDecode(response.body);
      });
    } else {
      _showErrorMessage('Failed to load exercise summary');
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

  Future<void> _fetchPastRecommendations() async {
    String? token = await AuthService().getAccessToken();
    final response = await http.get(
      Uri.parse('$apiUrl/virtual-health-coach/past-recommendations/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _pastRecommendations = List<Map<String, String>>.from(
            data['past_recommendations'].map((rec) => {
                  'timestamp': rec['generated_at'],
                  'recommendation': rec['recommendation']
                }));
      });
    } else {
      _showErrorMessage('Failed to load past recommendations');
    }
  }

  Future<void> _fetchHealthTrends(String period) async {
    String? token = await AuthService().getAccessToken();
    final response = await http.get(
      Uri.parse('$apiUrl/health-trends/$period/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        _healthTrends = jsonDecode(response.body)['trend'];
      });
    } else {
      _showErrorMessage('Failed to load health trends');
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

  void _navigateToChatbot() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatbotScreen(),
      ),
    );
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
                  _buildSectionTitle("Exercise Summary for Today"),
                  _exerciseSummary.isEmpty
                      ? _buildEmptyState("No exercise data available.")
                      : Card(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSummaryItem(
                                    "Steps", _exerciseSummary['steps']),
                                _buildSummaryItem("Calories Burned",
                                    _exerciseSummary['calories_burned']),
                                _buildSummaryItem("Distance",
                                    _exerciseSummary['distance_meters']),
                              ],
                            ),
                          ),
                        ),
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
                  const SizedBox(height: 20),
                  _buildSectionTitle("Weekly Health Trends"),
                  _healthTrends.isEmpty
                      ? _buildEmptyState("No trend data available.")
                      : Card(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSummaryItem("Avg Glucose",
                                    _healthTrends['avg_glucose_level']),
                                _buildSummaryItem(
                                    "Total Steps", _healthTrends['avg_steps']),
                                _buildSummaryItem("Avg Sleep",
                                    _healthTrends['avg_sleep_hours']),
                                _buildSummaryItem("Avg Heart Rate",
                                    _healthTrends['avg_heart_rate']),
                              ],
                            ),
                          ),
                        ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToChatbot,
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
    return Text("$label: ${value ?? 'N/A'}");
  }
}
