import 'package:glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GamificationGameHub extends StatefulWidget {
  const GamificationGameHub({super.key});

  @override
  _GamificationGameHubState createState() => _GamificationGameHubState();
}

class _GamificationGameHubState extends State<GamificationGameHub> {
  List quizSets = [];
  bool loading = true;
  final String? apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    fetchQuizSets();
  }

  Future<void> fetchQuizSets() async {
    final token = await AuthService().getAccessToken();
    if (token == null) return;

    final response = await http.get(
      Uri.parse('$apiUrl/gamification/quizsets/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        quizSets = json.decode(response.body);
        loading = false;
      });
    }
  }

  void _openLevel(int level, bool unlocked) {
    if (unlocked) {
      Navigator.pushNamed(context, '/gamification/module', arguments: level);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("🛑 Complete the previous level to unlock this one.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("🎮 Learning Adventure")),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                 SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _navButton(
                            context, "🏅 Achievements", '/gamification/stats',
                            icon: Icons.emoji_events),
                        const SizedBox(width: 12),
                        _navButton(
                            context, "🏆 Leaderboard", '/gamification/stats',
                            icon: Icons.leaderboard, tabIndex: 1),
                        const SizedBox(width: 12),
                        _navButton(
                            context, "📘 Attempts", '/gamification/attempts',
                            icon: Icons.history),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text("Select a Level",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: ListView.builder(
                      itemCount: quizSets.length,
                      itemBuilder: (context, index) {
                        final level = quizSets[index]['level'];
                        final title = quizSets[index]['title'];
                        final completed =
                            quizSets[index]['progress']['completed'];
                        final unlocked = index == 0 ||
                            quizSets[index - 1]['progress']['completed'];

                        return Card(
                          elevation: 4,
                          color: completed
                              ? Colors.green[100]
                              : (unlocked ? Colors.white : Colors.grey[300]),
                          child: ListTile(
                            leading: Icon(Icons.videogame_asset,
                                color: completed
                                    ? Colors.green
                                    : (unlocked ? Colors.blue : Colors.grey)),
                            title: Text("Level $level: $title"),
                            subtitle: Text(completed
                                ? "✅ Completed"
                                : (unlocked ? "🔓 Unlocked" : "🔒 Locked")),
                            onTap: () => _openLevel(level, unlocked),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _navButton(BuildContext context, String label, String route,
      {IconData? icon, int? tabIndex}) {
    return ElevatedButton.icon(
      icon: Icon(icon ?? Icons.navigate_next),
      label: Text(label, style: TextStyle(fontSize: 14)),
      onPressed: () {
        if (route == '/gamification/stats' && tabIndex != null) {
          Navigator.pushNamed(context, route, arguments: tabIndex);
        } else {
          Navigator.pushNamed(context, route);
        }
      },
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
      ),
    );
  }

}

