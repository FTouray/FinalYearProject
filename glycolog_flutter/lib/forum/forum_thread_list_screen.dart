import 'package:glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'forum_thread_screen.dart';
import 'forum_create_thread_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ForumThreadListScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const ForumThreadListScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<ForumThreadListScreen> createState() => _ForumThreadListScreenState();
}

class _ForumThreadListScreenState extends State<ForumThreadListScreen> {
  List threads = [];
  bool isLoading = true;
  final String? apiUrl = dotenv.env['API_URL'];

  Future<void> fetchThreads() async {
    final token = await AuthService().getAccessToken();
    final headers = {
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.get(
      Uri.parse("$apiUrl/forum/categories/${widget.categoryId}/threads/"),
      headers: headers,
    );

    if (response.statusCode == 200) {
      setState(() {
        threads = jsonDecode(response.body);
        isLoading = false;
      });
    } else {
      print(
          "Error fetching threads: ${response.statusCode} - ${response.body}");
    }
  }

  @override
  void initState() {
    super.initState();
    fetchThreads();
  }

  void refreshThreads() {
    fetchThreads();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        backgroundColor: Colors.blueAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => fetchThreads(),
              child: ListView(
                children: [
                  _buildCategoryHeader(),
                  const SizedBox(height: 10),
                  if (threads.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Text("No threads yet. Start the discussion!"),
                      ),
                    ),
                  ...threads.map((thread) => _buildThreadCard(thread)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueAccent,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ForumCreateThreadScreen(categoryId: widget.categoryId),
            ),
          );
          refreshThreads();
        },
        icon: const Icon(Icons.add),
        label: const Text("New Thread"),
      ),
    );
  }

  Widget _buildCategoryHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueAccent.shade400, Colors.blueAccent.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.forum, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(
            widget.categoryName,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            "Explore and join conversations in this topic.",
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadCard(dynamic thread) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading:
            const Icon(Icons.chat_bubble_outline, color: Colors.blueAccent),
        title: Text(
          thread['title'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
            "💬 ${thread['comment_count']}  •  🕒 ${thread['latest_reply'] ?? "No replies"}"),
        trailing:
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ForumThreadScreen(
              threadId: thread['id'].toString(),
              username: "current_user",
            ),
          ),
        ),
      ),
    );
  }
}
