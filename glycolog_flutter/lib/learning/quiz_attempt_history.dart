import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class QuizAttemptHistoryPage extends StatefulWidget {
  const QuizAttemptHistoryPage({super.key});

  @override
  State<QuizAttemptHistoryPage> createState() => _QuizAttemptHistoryPageState();
}

class _QuizAttemptHistoryPageState extends State<QuizAttemptHistoryPage> {
  List attempts = [];
  bool loading = true;
  final String? apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    fetchAttempts();
  }

  Future<void> fetchAttempts() async {
    final token = await AuthService().getAccessToken();
    if (token == null) return;
    final res = await http.get(
      Uri.parse('$apiUrl/gamification/attempts/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      setState(() {
        attempts = json.decode(res.body);
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("📊 Past Quiz Attempts")),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : attempts.isEmpty
              ? Center(child: Text("No attempts yet. Try a quiz!"))
              : ListView.builder(
                  itemCount: attempts.length,
                  padding: EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final attempt = attempts[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(Icons.school, color: Colors.indigo),
                        title: Text(
                            "Level ${attempt['level']}: ${attempt['title']}",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          "Score: ${attempt['score'].toStringAsFixed(1)}%\nXP: +${attempt['xp_earned']}\nDate: ${attempt['attempted_at']}",
                          style: TextStyle(fontSize: 13),
                        ),
                      onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/gamification/attempt-review',
                            arguments: attempt['review'],
                          );
                        },
                     
                      ),
                    );
                  },
                ),
    );
  }
}
