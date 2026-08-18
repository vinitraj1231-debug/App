import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  final UserModel contact;

  const ChatScreen({Key? key, required this.contact}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<ChatProvider>(context, listen: false).loadMessages(widget.contact.id);
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final provider = Provider.of<ChatProvider>(context, listen: false);
    provider.sendMessage(widget.contact.id, text);
    _messageController.clear();
    provider.sendTyping(widget.contact.id, false);

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final messages = chatProvider.chatMessages[widget.contact.id] ?? [];
    final isTyping = chatProvider.typingUsers[widget.contact.id] ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF0E1621), // Telegram Chat Background
      appBar: AppBar(
        backgroundColor: const Color(0xFF17212B),
        elevation: 1,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF229ED9),
              radius: 18,
              child: Text(
                widget.contact.fullName.isNotEmpty
                    ? widget.contact.fullName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.contact.fullName,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                Text(
                  isTyping
                      ? 'typing...'
                      : (widget.contact.isOnline ? 'online' : 'last seen recently'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isTyping ? const Color(0xFF229ED9) : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Network connection banner
          if (!chatProvider.isConnectedToInternet)
            Container(
              color: Colors.orangeDark,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const Text(
                'Waiting for network... Messages will auto-send once online.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),

          // Message list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg.senderId == chatProvider.currentUser?.id;

                return _buildMessageBubble(msg, isMe);
              },
            ),
          ),

          // Input field bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: const Color(0xFF17212B),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF242F3D),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        onChanged: (val) {
                          chatProvider.sendTyping(widget.contact.id, val.isNotEmpty);
                        },
                        decoration: const InputDecoration(
                          hintText: 'Message',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF229ED9),
                    radius: 22,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe) {
    final formattedTime = DateFormat('HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(msg.timestamp),
    );

    IconData statusIcon;
    Color statusColor = Colors.lightBlueAccent;

    if (msg.isPendingSync || msg.status == 'failed') {
      statusIcon = Icons.access_time_rounded; // Clock icon for offline unsent message
      statusColor = Colors.orangeAccent;
    } else if (msg.status == 'read') {
      statusIcon = Icons.done_all_rounded;
    } else if (msg.status == 'delivered') {
      statusIcon = Icons.done_all_rounded;
    } else {
      statusIcon = Icons.done_rounded;
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF2B5278) : const Color(0xFF182533),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 12),
          ),
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          cross: WrapCrossAlignment.end,
          spacing: 8,
          children: [
            Text(
              msg.content,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formattedTime,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(statusIcon, size: 14, color: statusColor),
                ]
              ],
            )
          ],
        ),
      ),
    );
  }
}
