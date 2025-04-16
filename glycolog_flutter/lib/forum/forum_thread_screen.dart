import 'dart:async';
import 'package:glycolog/services/forum_http_service.dart';
import 'package:flutter/material.dart';

class ForumThreadScreen extends StatefulWidget {
  final String threadId;
  final String username;

  const ForumThreadScreen({super.key, required this.threadId, required this.username});

  @override
  _ForumThreadScreenState createState() => _ForumThreadScreenState();
}

class _ForumThreadScreenState extends State<ForumThreadScreen> {
  late ForumHttpService httpService;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> messages = [];
  final Map<int, String> reactions = {}; // messageIndex -> emoji
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    httpService = ForumHttpService(threadId: widget.threadId);
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
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
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await httpService.sendMessage(widget.username, text);
    _controller.clear();
    final fetchedMessages = await httpService.fetchMessages();
    setState(() {
      messages.clear();
      messages.addAll(fetchedMessages);
    });
    _scrollToBottom();
  }

  String _formatTime(String timestamp) {
    try {
      final utcTime = DateTime.parse(timestamp).toLocal();
      return "${utcTime.hour.toString().padLeft(2, '0')}:${utcTime.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return '';
    }
  }

  void _showReactionPicker(int index) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['❤️', '🔥', '😆', '😢', '👍'].map((emoji) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  reactions[index] = emoji;
                });
                Navigator.pop(context);
              },
              child: Text(emoji, style: const TextStyle(fontSize: 30)),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Thread Discussion"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(child: Text("No messages yet. Start chatting!"))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isUser = msg['username'] == widget.username;
                      final time = _formatTime(msg['timestamp']);

                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: () => _showReactionPicker(index),
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                vertical: 4.0, horizontal: 10.0),
                            padding: const EdgeInsets.all(12.0),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? Colors.blueAccent[100]
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isUser ? 12 : 0),
                                bottomRight: Radius.circular(isUser ? 0 : 12),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isUser)
                                  Text(
                                    msg['username'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  msg['message'] ?? '',
                                  style: const TextStyle(fontSize: 15),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      time,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    if (reactions.containsKey(index))
                                      Text(
                                        reactions[index]!,
                                        style: const TextStyle(fontSize: 16),
                                      )
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Write your message...",
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: sendMessage,
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
