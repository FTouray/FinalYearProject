import 'dart:convert';
import 'package:glycolog/learning/xp_level_widget.dart';
import 'package:glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GamificationDashboardCard extends StatefulWidget {
  const GamificationDashboardCard({super.key});

  @override
  GamificationDashboardCardState createState() => GamificationDashboardCardState();
}

class GamificationDashboardCardState extends State<GamificationDashboardCard> {
  int level = 1;
  int xp = 0;
  int? nextLevelToContinue;
  String? nextTitle;
  final String? apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    fetchProgress();
  }

  Future<void> fetchProgress() async {
    final token = await AuthService().getAccessToken();
    if (token == null) throw Exception("User is not authenticated.");

    final response = await http.get(
      Uri.parse('$apiUrl/gamification/quizsets/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final profileRes = await http.get(
      Uri.parse('$apiUrl/user/profile/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200 && profileRes.statusCode == 200) {
      final data = json.decode(response.body);
      final profile = json.decode(profileRes.body);

      List quizsets = data['quiz_sets'] ?? []; 

      setState(() {
        xp = profile['xp'] ?? 0;
        level = profile['level'] ?? 1;
        bool foundNext = false;
        for (int i = 0; i < quizsets.length; i++) {
          if (quizsets[i]['progress'] != null &&
              quizsets[i]['progress']['completed'] == false) {
            nextLevelToContinue = quizsets[i]['level'];
            nextTitle = quizsets[i]['title'];
            foundNext = true;
            break;
          }
        }
        if (!foundNext) {
          nextLevelToContinue = null;
          nextTitle = null;
        }
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        XPLevelWidget(xp: xp, level: level),
        if (nextLevelToContinue != null)
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/gamification/module', arguments: nextLevelToContinue),
            child: Card(
              color: Colors.orange.shade100,
              margin: EdgeInsets.only(top: 12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.play_circle_fill, size: 32, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Continue where you left off",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text("Level $nextLevelToContinue: $nextTitle")
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 18)
                  ],
                ),
              ),
            ),
          )
      ],
    );
  }
}
