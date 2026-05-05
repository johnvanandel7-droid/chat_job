import 'package:chat_job/components/time_ago.dart';
//import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:chat_job/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_job/components/app_bar.dart';

final _firestore = FirebaseFirestore.instance;
final _auth = FirebaseAuth.instance;
//final _messaging = FirebaseMessaging.instance;

class ChatScreen extends StatefulWidget {
  static const id = 'chat_screen';

  final String chatId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
  });
  @override
  // ignore: library_private_types_in_public_api
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  String? currentUserEmail;
  String? currentUserUid;
  String chatTitle = '';
  String? otherUserUid;

  @override
  void initState() {
    super.initState();
    currentUserEmail = _auth.currentUser?.email?.trim().toLowerCase();
    currentUserUid = _auth.currentUser?.uid.trim();
    _loadChatInfo();
  }

  Future<void> _loadChatInfo() async {
    final doc = await _firestore.collection('chats').doc(widget.chatId).get();

    if (doc.exists) {
      final data = doc.data()!;

      final participants = List<String>.from(data['participantIds'] ?? []);
      setState(() {
        chatTitle = data['chatName'] ?? widget.otherUserName;
        otherUserUid = participants.firstWhere(
          (id) => id != currentUserUid,
          orElse: () => '',
        );
      });
    }
  }

  Future<void> sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || currentUserEmail == null) return;

    final chatRef = _firestore.collection('chats').doc(widget.chatId);

    final messageRef = chatRef.collection('messages').doc();

    try {
      // add the actual message
      await messageRef.set({
        'text': text,
        'senderEmail': currentUserEmail,
        'senderId': currentUserUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // update the parrent chat document
      await _firestore.collection('chats').doc(widget.chatId).update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUserUid,
      });

      if (otherUserUid == null || otherUserUid!.isEmpty) {
        print("No receiver found");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No receiver found for the message")),
        );
        return;
      }

      _messageController.clear();
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: MessagesStream(
                chatId: widget.chatId,
                currentUser: currentUserEmail,
              ),
            ),
            Container(
              decoration: kMessageContainerDecoration,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onSubmitted: (value) {
                        sendMessage();
                      },
                      decoration: kMessageTextFieldDecoration,
                    ),
                  ),
                  IconButton(
                    onPressed: sendMessage,
                    icon: Icon(Icons.send, color: Colors.black),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessagesStream extends StatelessWidget {
  final String chatId;
  final String? currentUser;
  const MessagesStream({
    super.key,
    required this.chatId,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No messages yet"));
        }

        final messages = snapshot.data!.docs; // already ordered by query

        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.all(10),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final data = messages[index].data() as Map<String, dynamic>;
            final text = data['text'] as String? ?? '';
            final senderEmail = data['senderEmail'] as String? ?? '';
            final ts = data['createdAt'] as Timestamp?;

            final isMe = senderEmail == currentUser;

            return MessageBubble(
              sender: senderEmail.split('@')[0],
              text: text,
              sendTime: formatTimeAgo(ts),
              isMe: isMe,
            );
          },
        );
      },
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String sender;
  final String text;
  final String sendTime;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.sender,
    required this.text,
    required this.sendTime,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Material(
            borderRadius: isMe
                ? BorderRadius.only(
                    topLeft: Radius.circular(30),
                    bottomLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  )
                : BorderRadius.only(
                    topLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
            elevation: 5,
            color: isMe ? Colors.blue : Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 10.0,
                horizontal: 20,
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 20,
                  color: isMe ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
          Text(
            '$sender • $sendTime',
            style: TextStyle(fontSize: 12, color: Colors.black),
          ),
        ],
      ),
    );
  }
}
