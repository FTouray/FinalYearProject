import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:glycolog/services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class QuizResultPage extends StatefulWidget {
  final Map<String, dynamic> result;
  const QuizResultPage({super.key, required this.result});

  @override
  State<QuizResultPage> createState() => _QuizResultPageState();
}

class _QuizResultPageState extends State<QuizResultPage> {
  late ConfettiController _confettiController;
  bool nextLevelUnlocked = false;
  final String? apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    if (widget.result['completed'] == true) {
      Future.delayed(Duration(milliseconds: 400), () {
        _confettiController.play();
      });
    }

    checkNextLevelUnlocked();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> checkNextLevelUnlocked() async {
    final token = await AuthService().getAccessToken();
    if (token == null) return;

    final response = await http.get(
      Uri.parse('$apiUrl/gamification/quizsets/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final unlockedLevels = List<int>.from(data['unlocked_levels'] ?? []);
      final nextLevel = (widget.result['quiz_set_level'] ?? 1) + 1;

      setState(() {
        nextLevelUnlocked = unlockedLevels.contains(nextLevel);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.result['score'] ?? 0.0;
    final completed = widget.result['completed'] ?? false;
    final xp = widget.result['xp_awarded'] ?? 0;
    final review =
        List<Map<String, dynamic>>.from(widget.result['review'] ?? []);
    final level = widget.result['quiz_set_level'] ?? 1;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text("🎉 Quiz Results")),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Icon(
                        completed
                            ? Icons.emoji_events_rounded
                            : Icons.school_rounded,
                        size: 80,
                        color: completed ? Colors.orange : Colors.blue,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        completed
                            ? "Well done! You’ve completed this level."
                            : "Nice try! Review and try again.",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text("Your Score: ${score.toStringAsFixed(1)}%",
                          style: TextStyle(fontSize: 16)),
                      Text("XP Earned: +$xp",
                          style: TextStyle(
                              fontSize: 14, color: Colors.green.shade700)),
                    ],
                  ),
                ),
                const Divider(height: 32),
                Text("📚 Review Questions:",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: review.length,
                    itemBuilder: (context, index) {
                      final q = review[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Q${index + 1}: ${q['question']}",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 8),
                              ...List<String>.from(q['options']).map((opt) {
                                final isCorrect = opt == q['correct_answer'];
                                final isChosen = opt == q['user_answer'];
                                final color = isCorrect
                                    ? Colors.green.shade100
                                    : (isChosen ? Colors.red.shade100 : null);
                                return Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: isCorrect
                                            ? Colors.green
                                            : (isChosen
                                                ? Colors.red
                                                : Colors.grey.shade300)),
                                  ),
                                                                    child: ListTile(
                                    title: Text(opt),
                                    trailing: isCorrect
                                        ? Icon(Icons.check, color: Colors.green)
                                        : (isChosen
                                            ? Icon(Icons.close,
                                                color: Colors.red)
                                            : null),
                                  ),
                                );
                              })
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(Icons.refresh),
                      label: Text("Retake Quiz"),
                      onPressed: () => Navigator.pushReplacementNamed(
                        context,
                        '/gamification/module',
                        arguments: level,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: Icon(Icons.home),
                      label: Text("Back to Home"),
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/home',
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                    if (completed && nextLevelUnlocked)
                      ElevatedButton.icon(
                        icon: Icon(Icons.arrow_forward),
                        label: Text("Next Quiz"),
                        onPressed: () {
                          Navigator.pushReplacementNamed(
                            context,
                            '/gamification/module',
                            arguments: level + 1,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              emissionFrequency: 0.05,
              maxBlastForce: 10,
              minBlastForce: 5,
              gravity: 0.3,
              colors: const [
                Colors.orange,
                Colors.green,
                Colors.blue,
                Colors.pink
              ],
            ),
          ),
        ],
      ),
    );
  }
}

 
