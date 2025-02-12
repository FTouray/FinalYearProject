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
  bool isLoading = false;
  final String? apiUrl = dotenv.env['API_URL']; 

  @override
  void initState() {
    super.initState();
    _fetchChatHistory();
    _fetchRecommendations();
  }

  Future<void> _fetchChatHistory() async {
    String? token = await AuthService().getAccessToken();
    final response = await http.get(
      Uri.parse('$apiUrl/get-chat-history/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _messages =
            List<Map<String, String>>.from(data['chat_history'].map((msg) => {
                  'role': msg['sender'],
                  'content': msg['message'],
                }));
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load chat history')),
      );
    }
  }

  Future<void> _fetchRecommendations() async {
    String? token = await AuthService().getAccessToken();
    final response = await http.get(
      Uri.parse('$apiUrl/get-past-recommendations/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _recommendations = List<Map<String, String>>.from(
            data['past_recommendations'].map((rec) => {
                  'timestamp': rec['timestamp'],
                  'recommendation': rec['recommendation'],
                }));
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load recommendations')),
      );
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
      Uri.parse('$apiUrl/chat-with-health-coach/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
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
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  void _navigateToRecommendations() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            RecommendationsScreen(recommendations: _recommendations),
      ),
    );
  }

  void _navigateToSmartwatchData() {
    Navigator.pushNamed(context, '/smartwatch-data');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Virtual Health Coach'),
        backgroundColor: Colors.blue[800],
        actions: [
          IconButton(
            icon: Icon(Icons.fitness_center),
            onPressed: _navigateToRecommendations,
            tooltip: 'View Recommendations',
          ),
          IconButton(
            icon: Icon(Icons.watch),
            onPressed: _navigateToSmartwatchData,
            tooltip: 'Smartwatch Data',
          ),
        ],
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

// Recommendations Screen to display past AI-generated recommendations
class RecommendationsScreen extends StatelessWidget {
  final List<Map<String, String>> recommendations;

  const RecommendationsScreen({super.key, required this.recommendations});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Exercise Recommendations'),
        backgroundColor: Colors.blue[800],
      ),
      body: ListView.builder(
        itemCount: recommendations.length,
        itemBuilder: (context, index) {
          final recommendation = recommendations[index];
          return Card(
            margin: EdgeInsets.all(8.0),
            child: ListTile(
              title: Text(recommendation['recommendation'] ?? ''),
              subtitle: Text('Date: ${recommendation['timestamp']}'),
            ),
          );
        },
      ),
    );
  }
}
