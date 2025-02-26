import 'package:flutter/material.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  _ChatbotScreenState createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, String>> _messages = [];
  bool isLoading = false;

  void _sendMessage(String message) {
    if (message.isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'content': message});
      isLoading = true;
    });

    // Simulate AI Response
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _messages
            .add({'role': 'assistant', 'content': "AI Response for: $message"});
        isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat with AI Coach')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return ListTile(
                  title: Text("${message['role']}: ${message['content']}"),
                );
              },
            ),
          ),
          TextField(
            controller: _controller,
            onSubmitted: (msg) {
              _sendMessage(msg);
              _controller.clear();
            },
          ),
        ],
      ),
    );
  }
}
