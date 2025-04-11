import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'forum_thread_screen.dart';
import 'forum_create_thread_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ForumThreadListScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const ForumThreadListScreen({Key? key, required this.categoryId, required this.categoryName}) : super(key: key);

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
      appBar: AppBar(title: Text(widget.categoryName)),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: threads.length,
              itemBuilder: (context, index) {
                final thread = threads[index];
                return ListTile(
                  title: Text(thread['title']),
                  subtitle: Text("Comments: ${thread['comment_count']}"),
                  trailing: Text(thread['latest_reply'] ?? "No replies"),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ForumThreadScreen(
                        threadId: thread['id'].toString(),
                        username: "current_user", 
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ForumCreateThreadScreen(categoryId: widget.categoryId),
            ),
          );
          refreshThreads(); // Refresh after adding thread
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
