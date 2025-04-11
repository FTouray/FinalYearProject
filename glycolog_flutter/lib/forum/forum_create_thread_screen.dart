import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ForumCreateThreadScreen extends StatefulWidget {
  final int categoryId;

  const ForumCreateThreadScreen({Key? key, required this.categoryId})
      : super(key: key);

  @override
  State<ForumCreateThreadScreen> createState() =>
      _ForumCreateThreadScreenState();
}

class _ForumCreateThreadScreenState extends State<ForumCreateThreadScreen> {
  final TextEditingController _titleController = TextEditingController();
  final String? apiUrl = dotenv.env['API_URL']; 

  Future<void> createThread() async {
  final token = await AuthService().getAccessToken(); 
  final headers = {
    'Content-Type': 'application/json',
  };
  if (token != null) {
    headers['Authorization'] = 'Bearer $token'; 
  }

  final response = await http.post(
    Uri.parse("$apiUrl/forum/threads/create/"),
    headers: headers,
    body: jsonEncode({
      "category_id": widget.categoryId,
      "title": _titleController.text,
    }),
  );

  if (response.statusCode == 201) {
    Navigator.pop(context); 
  } else {
    print("Failed to create thread: ${response.statusCode} - ${response.body}");
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Thread")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Thread Title"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: createThread,
              child: const Text("Create"),
            ),
          ],
        ),
      ),
    );
  }
}
