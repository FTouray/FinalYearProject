import 'dart:async';
import 'package:Glycolog/services/forum_http_service.dart';
import 'package:flutter/material.dart';

class ForumThreadScreen extends StatefulWidget {
  final String threadId;
  final String username;

  ForumThreadScreen({required this.threadId, required this.username});

  @override
  _ForumThreadScreenState createState() => _ForumThreadScreenState();
}

class _ForumThreadScreenState extends State<ForumThreadScreen> {
  late ForumHttpService httpService;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> messages = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    httpService = ForumHttpService(threadId: widget.threadId);
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(Duration(seconds: 3), (_) async {
      final fetchedMessages = await httpService.fetchMessages();
      setState(() {
        messages.clear();
        messages.addAll(fetchedMessages);
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await httpService.sendMessage(widget.username, text);
    _controller.clear();

    // Immediately fetch messages after sending
    final fetchedMessages = await httpService.fetchMessages();
    setState(() {
      messages.clear();
      messages.addAll(fetchedMessages);
    });
    _scrollToBottom();
  }

  String _formatTime(String timestamp) {
    try {
      final utcTime =
          DateTime.parse(timestamp).toLocal(); 
      return "${utcTime.hour.toString().padLeft(2, '0')}:${utcTime.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return '';
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Forum Thread")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final time = DateTime.tryParse(msg['timestamp'] ?? '');
                return Align(
                  alignment: msg['username'] == widget.username
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        vertical: 4.0, horizontal: 8.0),
                    padding: const EdgeInsets.all(12.0),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: msg['username'] == widget.username
                          ? Colors.blue[300]
                          : Colors.grey[300],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: Radius.circular(
                            msg['username'] == widget.username ? 12 : 0),
                        bottomRight: Radius.circular(
                            msg['username'] == widget.username ? 0 : 12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (msg['username'] != widget.username)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              msg['username'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            msg['message'] ?? '',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(msg['timestamp']),
                          style: const TextStyle(
                              fontSize: 10, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                );


              },
            ),
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration:
                        InputDecoration(hintText: "Type your message..."),
                  ),
                ),
                IconButton(icon: Icon(Icons.send), onPressed: sendMessage),
              ],
            ),
          )
        ],
      ),
    );
  }
}
