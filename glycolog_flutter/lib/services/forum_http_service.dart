import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:glycolog/services/auth_service.dart';

class ForumHttpService {
  final String threadId;
  final String? apiUrl = dotenv.env['API_URL'];

  ForumHttpService({required this.threadId});

  Future<Map<String, dynamic>?> sendMessage(
      String username, String message) async {
    final token = await AuthService().getAccessToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      "thread_id": threadId,
      "content": message,
    });

    final response = await http.post(
      Uri.parse("$apiUrl/forum/comments/create/"),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      print("Failed to send message: ${response.body}");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMessages() async {
    final response = await http.get(
      Uri.parse("$apiUrl/forum/threads/$threadId/comments/"),
    );

    if (response.statusCode == 200) {
      final raw = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(raw.map((msg) => {
            "id": msg["id"],
            "username": msg["username"],
            "content": msg["content"],
            "timestamp": msg["created_at"],
            "reactions": List<Map<String, dynamic>>.from(msg["reactions"] ?? [])
          }));
    } else {
      return [];
    }
  }

  Future<void> sendReaction(int commentId, String emoji) async {
    final token = await AuthService().getAccessToken();
    final apiUrl = dotenv.env['API_URL'];

    await http.post(
      Uri.parse('$apiUrl/forum/reactions/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'comment_id': commentId,
        'emoji': emoji,
      }),
    );
  }

}
