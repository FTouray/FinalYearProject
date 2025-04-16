import 'dart:convert';
import 'package:glycolog/services/auth_service.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PersonalTrendsWidget extends StatefulWidget {
  const PersonalTrendsWidget({super.key});

  @override
  PersonalTrendsWidgetState createState() => PersonalTrendsWidgetState();
}

class PersonalTrendsWidgetState extends State<PersonalTrendsWidget> {
  Map<String, dynamic> feedback = {};
  bool showAll = false;
  bool loading = true;
  final String? apiUrl = dotenv.env['API_URL'];
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    fetchFeedback();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> fetchFeedback() async {
    final token = await AuthService().getAccessToken();
    if (token == null) throw Exception("User is not authenticated.");

    final prefs = await SharedPreferences.getInstance();
    final glucoseUnit = prefs.getString('selectedUnit') ?? 'mg/dL';

    final res = await http.get(
      Uri.parse('$apiUrl/predictive-feedback/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Glucose-Unit': glucoseUnit,
      },
    );

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final feedbackData = data['predictive_feedback'] ?? {};

      if ((feedbackData['positive'] as List).isNotEmpty) {
        _confettiController.play();
      }

      setState(() {
        feedback = feedbackData;
        loading = false;
      });
    }
  }

  Widget _buildPriorityChip(String level) {
    final color = {
      'High': Colors.red,
      'Medium': Colors.orange,
      'Low': Colors.green
    }[level];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: color!.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        level,
        style:
            TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildSection(String title, List<String> items, IconData icon,
      Color color, String Function(String) priorityFunction) {
    if (items.isEmpty) return SizedBox.shrink();
    final displayItems = showAll ? items : items.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...displayItems.map((text) {
          final level = priorityFunction(text);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("• ",
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                _buildPriorityChip(level),
              ],
            ),
          );
        }),
        if (items.length > 2)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => showAll = !showAll),
              child: Text(showAll ? "See Less" : "See More"),
            ),
          ),
      ],
    );
  }

  String determinePriority(String text) {
    text = text.toLowerCase();
    if (text.contains("frequent") ||
        text.contains("consistent") ||
        text.contains("persistent") ||
        text.contains("high glycaemic index") ||
        text.contains("elevated glucose")) {
      return "High";
    } else if (text.contains("may") ||
        text.contains("linked") ||
        text.contains("might") ||
        text.contains("suggest")) {
      return "Medium";
    } else {
      return "Low";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    if (feedback.isEmpty || (feedback['all']?.isEmpty ?? true)) {
      return _buildEmptyState();
    }

    List<String> positive = List<String>.from(feedback['positive'] ?? []);
    List<String> trend = List<String>.from(feedback['trend'] ?? []);
    List allRaw = feedback['all'] ?? [];

    List<String> shapOnly = allRaw
        .map((item) => item['text'] as String)
        .where((text) => !positive.contains(text) && !trend.contains(text))
        .toList();

    return Stack(
      children: [
        Card(
          color: Colors.teal.shade50,
          margin: const EdgeInsets.only(top: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "📊 Personal Trends & AI Insights",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildSection("✅ Positive Improvements", positive,
                    Icons.thumb_up_alt_outlined, Colors.green, (_) => "Low"),
                _buildSection("📈 Trends & Patterns", trend, Icons.trending_up,
                    Colors.deepPurple, determinePriority),
                _buildSection(
                    "🧠 AI Coach Insights",
                    shapOnly,
                    Icons.psychology_alt_outlined,
                    Colors.teal,
                    determinePriority),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 25,
            colors: const [
              Colors.green,
              Colors.orange,
              Colors.blue,
              Colors.pink
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: Colors.grey.shade100,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.insights_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                "No personal trends available yet.",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                "Once you start logging more meals, glucose, and symptoms, your trends will appear here.",
                style: TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
