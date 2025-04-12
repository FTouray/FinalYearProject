import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AchievementsAndLeaderboard extends StatefulWidget {
  @override
  _AchievementsAndLeaderboardState createState() =>
      _AchievementsAndLeaderboardState();
}

class _AchievementsAndLeaderboardState extends State<AchievementsAndLeaderboard>
    with SingleTickerProviderStateMixin {
  List achievements = [];
  List leaderboard = [];
  bool loading = true;
  late TabController tabController;
  final String? apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this); 
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final initialTab = ModalRoute.of(context)?.settings.arguments as int? ?? 0;
    tabController.index = initialTab;
    fetchData();
  }

  Future<void> fetchData() async {
    final token = await AuthService().getAccessToken();
    if (token == null) return;
    final headers = {'Authorization': 'Bearer $token'};

    final aRes = await http.get(
      Uri.parse('$apiUrl/gamification/achievements/'),
      headers: headers,
    );
    final lRes = await http.get(
      Uri.parse('$apiUrl/gamification/leaderboard/'),
    );

    if (aRes.statusCode == 200 && lRes.statusCode == 200) {
      setState(() {
        achievements = json.decode(aRes.body);
        leaderboard = json.decode(lRes.body);
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("🏅 Achievements & Leaderboard"),
        bottom: TabBar(
          controller: tabController,
          tabs: [
            Tab(text: "Achievements"),
            Tab(text: "Leaderboard"),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.home),
            tooltip: 'Back to Home',
            onPressed: () => Navigator.popUntil(
              context,
              (route) => route.settings.name == '/home',
            ),
          ),
        ],
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: tabController,
              children: [
                // Achievements Tab
                ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: achievements.length,
                  itemBuilder: (context, index) {
                    final badge = achievements[index];
                    return Card(
                      elevation: 4,
                      child: ListTile(
                        leading: Icon(Icons.emoji_events, color: Colors.amber),
                        title: Text(badge['badge_name'] ?? 'Badge'),
                        subtitle: Text(
                            "+${badge['points']} XP\n${badge['awarded_at']}",
                            style: TextStyle(fontSize: 13)),
                      ),
                    );
                  },
                ),

                // Leaderboard Tab
                ListView.separated(
                  padding: EdgeInsets.all(16),
                  itemCount: leaderboard.length,
                  separatorBuilder: (_, __) => Divider(),
                  itemBuilder: (context, index) {
                    final user = leaderboard[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text("${index + 1}")),
                      title: Text(user['username'] ?? 'User'),
                      trailing: Text("${user['points']} pts"),
                    );
                  },
                )
              ],
            ),
    );
  }
}
