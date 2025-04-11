import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:Glycolog/services/auth_service.dart';

class ForumHttpService {
  final String threadId;
  final String? apiUrl = dotenv.env['API_URL'];

  ForumHttpService({required this.threadId});

  Future<void> sendMessage(String username, String message) async {
    final token = await AuthService().getAccessToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      "thread_id": threadId,
      "content": message,
    });

    await http.post(
      Uri.parse("$apiUrl/forum/comments/create/"),
      headers: headers,
      body: body,
    );
  }

  Future<List<Map<String, dynamic>>> fetchMessages() async {
    final response = await http.get(
      Uri.parse("$apiUrl/forum/threads/$threadId/comments/"),
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      return [];
    }
  }
}
