import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ChatbotScreenState createState() => ChatbotScreenState();
}

class ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  final String? apiUrl = dotenv.env['API_URL'];

  int _currentPage = 1;
  bool _isFetchingMore = false;
  bool _hasMorePages = true;

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
              _scrollController.position.minScrollExtent &&
          !_isFetchingMore &&
          _hasMorePages) {
        _loadMoreMessages();
      }
    });
  }

  Future<void> _loadInitialMessages() async {
    _messages.clear();
    _currentPage = 1;
    await _loadMoreMessages();
  }

   Future<void> _loadMoreMessages() async {
    _isFetchingMore = true;
    String? token = await _getAccessToken();
    if (token == null) return;

    final response = await http.get(
      Uri.parse('$apiUrl/dashboard/chat/history/?page=$_currentPage'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> messages = data['chat_history'];

      if (messages.isEmpty) {
        setState(() => _hasMorePages = false);
      } else {
        setState(() {
          _messages.insertAll(
            0,
            messages.reversed.map<Map<String, String>>(
              (m) => {'role': m['sender'], 'content': m['message']},
            ),
          );
          _currentPage++;
        });
      }
    }

    _isFetchingMore = false;
  }

  Future<void> _sendMessage(String message) async {
    if (message.isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'content': message});
    });

    String? token = await _getAccessToken();
    if (token == null) return;

    final prefs = await SharedPreferences.getInstance();
    final unit = prefs.getString('selectedUnit') ?? 'mg/dL';

    final response = await http.post(
      Uri.parse('$apiUrl/dashboard/chat/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'message': message, 'unit': unit,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _messages.add({'role': 'assistant', 'content': data['response']});
      });
      _saveChatHistory(); // Save conversation locally
    } else {
      print('Failed to get AI response');
    }
  }

  
  Future<void> _saveChatHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_history', jsonEncode(_messages));
  }

  Future<String?> _getAccessToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with AI Coach'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true, // Show newest messages at bottom
              controller: _scrollController,
              itemCount: _messages.length + 1,
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _hasMorePages
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : const SizedBox.shrink();
                }

                final message = _messages[_messages.length - index - 1];
                return Align(
                  alignment: message['role'] == 'user'
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: message['role'] == 'user'
                          ? Colors.blue[300]
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${message['content']}",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    _sendMessage(_controller.text);
                    _controller.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
