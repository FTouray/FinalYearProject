import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VirtualHealthCoachScreen extends StatefulWidget {
  const VirtualHealthCoachScreen({super.key});

  @override
  _VirtualHealthCoachScreenState createState() =>
      _VirtualHealthCoachScreenState();
}

class _VirtualHealthCoachScreenState extends State<VirtualHealthCoachScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, String>> _messages = [];
  List<Map<String, String>> _recommendations = [];
  List<Map<String, String>> _notifications = [];
  Map<String, dynamic> _healthTrends = {};
  bool isLoading = false;
  final String? apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    _fetchChatHistory();
    _fetchRecommendations();
    _fetchNotifications();
    _fetchHealthTrends("weekly");
  }

  Future<void> _fetchChatHistory() async {
    String? token = await AuthService().getAccessToken();
    final response = await http.get(
      Uri.parse('$apiUrl/virtual-health-coach/chat/history/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _messages = List<Map<String, String>>.from(data['chat_history']
            .map((msg) => {'role': msg['sender'], 'content': msg['message']}));
      });
    } else {
      _showErrorMessage('Failed to load chat history');
    }
  }

  Future<void> _fetchRecommendations() async {
    String? token = await AuthService().getAccessToken();
    final response = await http.get(
      Uri.parse('$apiUrl/virtual-health-coach/recommendations/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _recommendations = List<Map<String, String>>.from(
            data['past_recommendations'].map((rec) => {
                  'timestamp': rec['generated_at'],
                  'recommendation': rec['recommendation']
                }));
      });
    } else {
      _showErrorMessage('Failed to load recommendations');
    }
  }

  Future<void> _fetchNotifications() async {
    String? token = await AuthService().getAccessToken();
    final response = await http.get(
      Uri.parse('$apiUrl/local-notifications/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _notifications = List<Map<String, String>>.from(data['notifications']
            .map((notif) => {'message': notif['message']}));
      });
    } else {
      _showErrorMessage('Failed to load notifications');
    }
  }

  Future<void> _fetchHealthTrends(String period) async {
    String? token = await AuthService().getAccessToken();
    final response = await http.get(
      Uri.parse('$apiUrl/health-trends/$period/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _healthTrends = data['trend'];
      });
    } else {
      _showErrorMessage('Failed to load health trends');
    }
  }

  Future<void> _sendMessage(String message) async {
    if (message.isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'content': message});
      isLoading = true;
    });

    String? token = await AuthService().getAccessToken();
    final response = await http.post(
      Uri.parse('$apiUrl/virtual-health-coach/chat/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: json.encode({'message': message}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _messages.add({'role': 'assistant', 'content': data['response']});
        isLoading = false;
      });
    } else {
      _showErrorMessage('Failed to send message');
      setState(() => isLoading = false);
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Virtual Health Coach'),
        backgroundColor: Colors.blue[800],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return ListTile(
                  title: Align(
                    alignment: message['role'] == 'user'
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: message['role'] == 'user'
                            ? Colors.blue[100]
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(message['content'] ?? ''),
                    ),
                  ),
                );
              },
            ),
          ),
          if (isLoading) const CircularProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask a question...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
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
