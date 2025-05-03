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
  List<String> predictedSymptoms = [];


  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    maybeRetrainModel().then((_) {
      fetchFeedback();
    });
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
    final feedbackData = Map<String, dynamic>.from(data['predictive_feedback'] ?? {});

    final nowTimestamp = DateTime.now();
    const daysThreshold = 30; 

    List<Map<String, dynamic>> allRaw = List<Map<String, dynamic>>.from(feedbackData['all'] ?? []);
    allRaw = allRaw.where((item) {
      final createdAt = DateTime.tryParse(item['timestamp'] ?? '') ?? nowTimestamp;
      return nowTimestamp.difference(createdAt).inDays <= daysThreshold;
    }).toList();

    setState(() {
      feedback = {
        'positive': feedbackData['positive'] ?? [],
        'trend': feedbackData['trend'] ?? [],
        'all': allRaw,
      };
      final rawSymptoms = feedbackData['predicted_symptoms'] ?? [];
        predictedSymptoms = List<String>.from(rawSymptoms.map((s) =>
            s is Map ? "${s['symptom']} — ${s['reason']}" : s.toString()));

      loading = false;
    });

    if ((feedback['positive'] as List?)?.isNotEmpty ?? false) {
      _confettiController.play();
    }

    print("✅ Loaded fresh predictive feedback: $feedback");
  } else {
    throw Exception("Failed to load predictive feedback (${res.statusCode}).");
  }
}


  Future<void> maybeRetrainModel() async {
    final token = await AuthService().getAccessToken();
    if (token == null) throw Exception("User is not authenticated.");

    final res = await http.get(
      Uri.parse('$apiUrl/check-retrain-model/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      print("✅ Maybe retrain model response: $data");
    } else {
      print("⚠️ Failed to check retrain model (${res.statusCode}).");
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
    List<Map<String, dynamic>> allRaw =
        List<Map<String, dynamic>>.from(feedback['all'] ?? []);

    List<String> shapOnly = allRaw
        .map((item) => item['text'] as String)
        .where((text) => !positive.contains(text) && !trend.contains(text))
        .toList();

    // Group and clean SHAP feedback properly
    Map<String, Set<String>> symptomReasons = {};

    for (var text in shapOnly) {
      for (var symptom in [
        "Fatigue",
        "Headaches",
        "Dizziness",
        "Thirst",
        "Nausea",
        "Blurred Vision",
        "Irritability",
        "Sweating",
        "Frequent Urination",
        "Dry Mouth",
        "Slow Wound Healing",
        "Weight Loss",
        "Increased Hunger",
        "Shakiness",
        "Hunger",
        "Fast Heartbeat"
      ]) {
        if (text.toLowerCase().startsWith(symptom.toLowerCase())) {
          final splitParts = text.split("is more likely");
          if (splitParts.length > 1) {
            final reasons = splitParts[1]
                .replaceAll(".", "")
                .replaceAll(" and ", ", ")
                .split(",")
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toSet();

            symptomReasons.putIfAbsent(symptom, () => {}).addAll(reasons);
          }
          break;
        }
      }
    }

    List<Map<String, dynamic>> processedShap = [];
    symptomReasons.forEach((symptom, reasons) {
      final reasonList = reasons.toList();
      if (reasonList.length > 1) {
        final lastReason = reasonList.removeLast();
        final mergedReasons = "${reasonList.join(", ")} and $lastReason";
        final cleanSentence = "$symptom is more likely $mergedReasons.";
        final priority = determinePriority(cleanSentence);
        processedShap.add({"text": cleanSentence, "priority": priority});
      } else if (reasonList.isNotEmpty) {
        final cleanSentence = "$symptom is more likely ${reasonList.first}.";
        final priority = determinePriority(cleanSentence);
        processedShap.add({"text": cleanSentence, "priority": priority});
      }
    });

    processedShap.sort((a, b) {
      const order = {"High": 0, "Medium": 1, "Low": 2};
      return order[a['priority']]!.compareTo(order[b['priority']]!);
    });

    // Also: sort Trends
    List<Map<String, dynamic>> sortedTrends = trend
        .map((text) => {"text": text, "priority": determinePriority(text)})
        .toList();

    sortedTrends.sort((a, b) {
      const order = {"High": 0, "Medium": 1, "Low": 2};
      return order[a['priority']]!.compareTo(order[b['priority']]!);
    });

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
                    if (predictedSymptoms.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Icon(Icons.health_and_safety,
                          color: Colors.indigo, size: 20),
                      SizedBox(width: 6),
                      Text(
                        "🔮 Predicted Symptoms",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...predictedSymptoms
                      .take(showAll ? predictedSymptoms.length : 3)
                      .map((symptomInfo) {
                    final parts = symptomInfo.split(" — ");
                    final symptom = parts.first.trim();
                    final reason = parts.length > 1 ? parts.last.trim() : "";

                    final match = RegExp(r'(.*?)(\.? You|\.? Your|\.? [A-Z])')
                        .firstMatch(reason);
                    final mainPart =
                        match != null ? match.group(1) ?? reason : reason;
                    final details = reason.replaceFirst(mainPart, "").trim();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("⚠️ $symptom",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text("Be careful — $mainPart.",
                              style: const TextStyle(fontSize: 14)),
                          if (details.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                details,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.black87),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  if (predictedSymptoms.length > 3)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() => showAll = !showAll),
                        child: Text(showAll ? "See Less" : "See More"),
                      ),
                    ),
                ],

                _buildGroupedSection(
                  "📈 Trends & Patterns",
                  sortedTrends,
                  Icons.trending_up,
                  Colors.deepPurple,
                ),
                _buildGroupedSection(
                  "🧠 AI Coach Insights",
                  processedShap,
                  Icons.psychology_alt_outlined,
                  Colors.teal,
                ),
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
                  child: Text(text, style: const TextStyle(fontSize: 14)),
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

  Widget _buildGroupedSection(String title, List<Map<String, dynamic>> items,
      IconData icon, Color color) {
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
        ...displayItems.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("• ",
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Expanded(
                  child:
                      Text(item['text'], style: const TextStyle(fontSize: 14)),
                ),
                _buildPriorityChip(item['priority']),
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
}
