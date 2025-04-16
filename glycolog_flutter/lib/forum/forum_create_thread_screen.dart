import 'package:glycolog/services/auth_service.dart';
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
  bool isSubmitting = false;
  String? errorText;

  Future<void> createThread() async {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      setState(() => errorText = "Title cannot be empty.");
      return;
    }

    setState(() {
      isSubmitting = true;
      errorText = null;
    });

    final token = await AuthService().getAccessToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = await http.post(
      Uri.parse("$apiUrl/forum/threads/create/"),
      headers: headers,
      body: jsonEncode({
        "category_id": widget.categoryId,
        "title": title,
      }),
    );

    setState(() => isSubmitting = false);

    if (response.statusCode == 201) {
      Navigator.pop(context);
    } else {
      setState(() {
        errorText = "Failed to create thread (code ${response.statusCode})";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📝 Create Thread"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: "Thread Title",
                hintText: "What’s your topic?",
                prefixIcon: const Icon(Icons.title),
                errorText: errorText,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : createThread,
                icon: const Icon(Icons.send),
                label: Text(isSubmitting ? "Creating..." : "Create Thread"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
