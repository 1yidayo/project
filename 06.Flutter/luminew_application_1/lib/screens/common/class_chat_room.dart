import 'package:flutter/material.dart';
// 修正：導入 services 和 services 的絕對路徑
import 'package:luminew_application_1/services/firebase_service.dart';

class ClassChatRoom extends StatefulWidget {
  final String chatKey; // 'public' or Class ID
  final String userId;
  final String title;

  const ClassChatRoom({
    super.key,
    required this.chatKey,
    required this.userId,
    this.title = '公共交流區',
  });

  @override
  State<ClassChatRoom> createState() => _ClassChatRoomState();
}

class _ClassChatRoomState extends State<ClassChatRoom> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _userName = '使用者'; // 用於發送訊息時的名稱

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final name = await firebaseService.getUserName(widget.userId);
    if (mounted) {
      setState(() {
        _userName = name;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    firebaseService.sendChatMessage(
      _messageController.text,
      widget.userId,
      widget.chatKey,
      _userName, // 傳送使用者名稱
    );

    _messageController.clear();
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  bool _isCurrentUser(String senderId) {
    return senderId == widget.userId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.chatKey != 'public'
          ? AppBar(title: Text(widget.title))
          : null, // 公共聊天室不需要獨立的 AppBar
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: firebaseService.getChatStream(widget.chatKey),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("尚無訊息"));
                }

                final messages = snapshot.data!;
                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _buildChatMessageBubble(message);
                  },
                );
              },
            ),
          ),
          // 輸入框
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: "以 $_userName 身份輸入訊息...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.send,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessageBubble(Map<String, dynamic> message) {
    final senderId = message['senderId'] ?? '';
    final senderName = message['senderName'] ?? '未知';
    final messageContent = message['content'] ?? '';
    final isMyMessage = _isCurrentUser(senderId);

    return Align(
      alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMyMessage
              ? Theme.of(context).primaryColor
              : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12).copyWith(
            topLeft: isMyMessage
                ? const Radius.circular(12)
                : const Radius.circular(0),
            topRight: isMyMessage
                ? const Radius.circular(0)
                : const Radius.circular(12),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMyMessage
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMyMessage)
              Text(
                senderName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: isMyMessage ? Colors.white70 : Colors.black54,
                ),
              ),
            Text(
              messageContent,
              style: TextStyle(
                color: isMyMessage ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
