import 'dart:async';
import 'package:flutter/material.dart';
import 'package:glycolog/services/forum_http_service.dart';

class ForumThreadScreen extends StatefulWidget {
  final String threadId;
  final String username;

  const ForumThreadScreen({
    super.key,
    required this.threadId,
    required this.username,
  });

  @override
  ForumThreadScreenState createState() => ForumThreadScreenState();
}

class ForumThreadScreenState extends State<ForumThreadScreen> {
  late ForumHttpService httpService;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> messages = [];
  Timer? _pollingTimer;
  bool isLoading = true;
  String? quotedMessage;

  @override
  void initState() {
    super.initState();
    httpService = ForumHttpService(threadId: widget.threadId);
    _startPolling();
    _fetchMessages();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _fetchMessages();
    });
  }

  Future<void> _fetchMessages() async {
    final fetchedMessages = await httpService.fetchMessages();
    setState(() {
      messages.clear();
      messages.addAll(fetchedMessages);
      isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
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

    String fullMessage =
        quotedMessage != null ? "> ${quotedMessage!}\n$text" : text;

    final response =
        await httpService.sendMessage(widget.username, fullMessage);

    _controller.clear();
    setState(() => quotedMessage = null);

    if (response != null) {
      setState(() {
        messages.add({
          'id': response['comment']['id'],
          'content': response['comment']['content'],
          'username': response['comment']['username'],
          'timestamp': response['comment']['created_at'],
          'reactions': [],
        });
      });
      _scrollToBottom();
    }
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
    final msg = messages[index];
    final commentId = msg['id'];

    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['❤️', '🔥', '😆', '😢', '👍'].map((emoji) {
            return GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                await httpService.sendReaction(commentId, emoji);
                await _fetchMessages();
              },
              child: Text(emoji, style: const TextStyle(fontSize: 30)),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showQuoteOption(int index) {
    final msg = messages[index];
    final content = msg['content'] ?? '';
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.format_quote),
              title: Text('Reply with Quote'),
              onTap: () {
                Navigator.pop(context);
                setState(() => quotedMessage = content);
                FocusScope.of(context).requestFocus(FocusNode());
              },
            ),
          ],
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
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? const Center(
                        child: Text("No messages yet. Start chatting!"))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isUser = msg['username']?.toLowerCase() ==
                              widget.username.toLowerCase();
                          final time = _formatTime(msg['timestamp']);
                          final List<dynamic> reactionList =
                              msg['reactions'] ?? [];

                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: GestureDetector(
                              onLongPress: () => _showQuoteOption(index),
                              onDoubleTap: () => _showReactionPicker(index),
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
                                    bottomLeft:
                                        Radius.circular(isUser ? 12 : 0),
                                    bottomRight:
                                        Radius.circular(isUser ? 0 : 12),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: isUser
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
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
                                      msg['content'] ?? '',
                                      textAlign: isUser
                                          ? TextAlign.right
                                          : TextAlign.left,
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
                                              color: Colors.black54),
                                        ),
                                        if (reactionList.isNotEmpty)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: reactionList.map((r) {
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 4.0),
                                                child: Chip(
                                                  label: Text(
                                                    "${r['emoji']} ${r['count']}",
                                                    style: const TextStyle(
                                                        fontSize: 12),
                                                  ),
                                                  backgroundColor:
                                                      Colors.grey.shade300,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 0),
                                                ),
                                              );
                                            }).toList(),
                                          ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (quotedMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Replying to: "$quotedMessage"',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => quotedMessage = null),
                        ),
                      ],
                    ),
                  ),
                Row(
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
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
