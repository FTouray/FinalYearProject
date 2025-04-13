import 'dart:convert';
import 'package:Glycolog/services/auth_service.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PredictiveFeedbackWidget extends StatefulWidget {
  @override
  _PredictiveFeedbackWidgetState createState() =>
      _PredictiveFeedbackWidgetState();
}

class _PredictiveFeedbackWidgetState extends State<PredictiveFeedbackWidget> {
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
      headers: {'Authorization': 'Bearer $token',
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

List<String> aggregateFeedback(List raw) {
    final Map<String, List<String>> symptomMap = {};

    for (var item in raw) {
      final text = item['text'] ?? '';
      final lower = text.toLowerCase();

      final keywords = [
        'nausea',
        'thirst',
        'fatigue',
        'dizziness',
        'irritability',
        'headaches',
        'blurred vision',
        'frequent urination'
      ];

      final symptom = keywords.firstWhere(
        (kw) => lower.contains(kw),
        orElse: () => '',
      );

      if (symptom.isNotEmpty) {
        symptomMap.putIfAbsent(symptom, () => []).add(text);
      } else {
        symptomMap.putIfAbsent(text, () => [text]);
      }
    }

    final results = symptomMap.entries.map((entry) {
      final symptom = entry.key;
      final Set<String> causes = {}; // Use Set to ensure uniqueness

      for (var text in entry.value) {
        var cleaned = text
            .replaceAll(RegExp(r'^we detected\s+', caseSensitive: false), '')
            .replaceAll(RegExp(symptom, caseSensitive: false), '')
            .replaceAll(
                RegExp(r'may be linked to[:]*', caseSensitive: false), '')
            .replaceAll(RegExp(r'is more likely', caseSensitive: false), '')
            .replaceAll(RegExp(r'\.*$'), '') // remove trailing periods
            .trim();

        if (cleaned.isNotEmpty) {
          causes.add(cleaned); // Add unique phrase
        }
      }

      if (causes.isEmpty) return entry.value.first;

      final uniqueCauses = causes.toList();
      final causeSentence = uniqueCauses.length > 1
          ? uniqueCauses.sublist(0, uniqueCauses.length - 1).join(', ') +
              ' or ' +
              uniqueCauses.last
          : uniqueCauses.first;

      return "Your ${symptom[0].toUpperCase()}${symptom.substring(1)} is more likely $causeSentence.";
        }).toSet().toList();

      return results;
  }


@override
  Widget build(BuildContext context) {
    if (loading || feedback.isEmpty) return const SizedBox();

    List<String> positive = List<String>.from(feedback['positive'] ?? []);
    List<String> trend = List<String>.from(feedback['trend'] ?? []);
    List allRaw = feedback['all'] ?? [];

    final List<String> aggregated = aggregateFeedback(allRaw);

    // Merge trends and SHAP-based messages into the full set
    final List<String> fullFeedback = [...trend, ...aggregated];

    // Summary will still be the top 2 from each
    final List<String> summary = [...positive.take(2), ...trend.take(2)];

    final displayed = showAll ? fullFeedback : summary;

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
                  "📊 Predictive Feedback",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...displayed.map((text) {
                  final isPositive = text.toString().startsWith("✅");
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isPositive ? Icons.verified : Icons.insights_outlined,
                          color: isPositive ? Colors.green : Colors.teal[900],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "• $text",
                            style: TextStyle(
                              fontSize: 14,
                              color: isPositive
                                  ? Colors.green[900]
                                  : Colors.teal[900],
                              fontWeight: isPositive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                if (fullFeedback.length > summary.length)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      child: Text(showAll ? "See Less" : "See More"),
                      onPressed: () => setState(() => showAll = !showAll),
                    ),
                  )
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

}
