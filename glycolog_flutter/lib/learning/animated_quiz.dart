import 'package:glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AnimatedQuizPage extends StatefulWidget {
  final int level;
  const AnimatedQuizPage({super.key, required this.level});

  @override
  State<AnimatedQuizPage> createState() => _AnimatedQuizPageState();
}

class _AnimatedQuizPageState extends State<AnimatedQuizPage> {
  List quizzes = [];
  List<String?> answers = [];
  int current = 0;
  bool loading = true;
  bool submitting = false;
  final String? apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    fetchQuiz();
  }

  Future<void> fetchQuiz() async {
   final token = await AuthService().getAccessToken();
    if (token == null) return;

    final response = await http.get(
      Uri.parse('$apiUrl/gamification/quizsets/${widget.level}/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        quizzes = data['quizzes'];
        quizzes.shuffle();
        answers = List.filled(quizzes.length, null);
        loading = false;
      });
    }
  }

  void selectAnswer(String answer) {
    setState(() => answers[current] = answer);
    Future.delayed(Duration(milliseconds: 300), () {
      if (current < quizzes.length - 1) {
        setState(() => current++);
      } else {
        submitQuiz();
      }
    });
  }

  Future<void> submitQuiz() async {
    setState(() => submitting = true);
    final token = await AuthService().getAccessToken();
    if (token == null) return;
    print('Submitting token: $token');

    final res = await http.post(
      Uri.parse('$apiUrl/gamification/submit-quiz/${widget.level}/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: json.encode({'answers': answers}),
    );

    if (res.statusCode == 200) {
      final result = json.decode(res.body);
      Navigator.pushNamed(context, '/gamification/result', arguments: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    final question = quizzes[current];
    final options = List<String>.from(question['options']);
    options.shuffle();

    return Scaffold(
      appBar: AppBar(title: Text('Level ${widget.level}')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (current + 1) / quizzes.length,
              backgroundColor: Colors.grey[300],
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 20),
            Text(
              'Q${current + 1}: ${question['question']}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...options.map((opt) => AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  margin: EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blueAccent),
                  ),
                  child: ListTile(
                    title: Text(opt),
                    onTap: () => selectAnswer(opt),
                  ),
                ))
          ],
        ),
      ),
    );
  }
}
