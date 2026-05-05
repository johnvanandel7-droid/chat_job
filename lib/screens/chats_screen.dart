import 'package:chat_job/components/app_bar.dart';
import 'package:chat_job/components/time_ago.dart';
import 'package:chat_job/screens/chat.dart';
import 'package:chat_job/screens/create_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final _auth = FirebaseAuth.instance;
final _firestore = FirebaseFirestore.instance;

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});
  static const id = 'chats_screen';

  @override
  Widget build(BuildContext context) {
    final currentUserEmail = _auth.currentUser?.email?.trim().toLowerCase();
    final currentUserUid = _auth.currentUser?.uid;
    print(currentUserUid);

    if (currentUserUid == null) {
      return Scaffold(body: Center(child: Text('Please log in')));
    }

    return Scaffold(
      appBar: AppBarWidget(),
      body: Column(
        children: [
          MaterialButtonWidget(
            onPressed: () {
              Navigator.pushNamed(context, CreateChatScreen.id);
            },
            chatName: 'Create A Chat',
          ),
          Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .where('participantIds', arrayContains: currentUserUid)
                  .orderBy('lastMessageTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("No chats yet.\nStart a new chat!"),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final chatId = doc.id;

                    // safe extraction

                    final chatName = data['chatName'] as String? ?? '';
                    // final participantIds = List<String>.from(
                    //   data['participantIds'] ?? [],
                    // );
                    final participantEmails = List<String>.from(
                      data['participantEmails'] ?? [],
                    );
                    final lastMessage =
                        data['lastMessage'] as String? ?? 'No messages yet';
                    final lastMessageSender =
                        data['lastMessageSender'] as String? ?? '';
                    final shortenedLastMessageSender =
                        lastMessageSender.length > 5
                        ? lastMessageSender.substring(0, 5)
                        : lastMessageSender;

                    bool isGroup =
                        data['isGroup'] == true || participantEmails.length > 2;

                    String displayName = chatName.isNotEmpty
                        ? chatName
                        : (isGroup
                              ? 'Group (${participantEmails.length})'
                              : participantEmails
                                    .firstWhere(
                                      (e) => e != currentUserEmail,
                                      orElse: () => 'Unknown',
                                    )
                                    .split('@')[0]);

                    return ListTile(
                      leading: CircleAvatar(
                        child: Icon(isGroup ? Icons.group : Icons.person),
                      ),
                      title: Text(
                        displayName,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '$shortenedLastMessageSender said: $lastMessage',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        formatTimeAgo(data['lastMessageTime'] as Timestamp?),
                        style: TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              chatId: chatId,
                              otherUserName: displayName,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MaterialButtonWidget extends StatelessWidget {
  final VoidCallback onPressed;
  final String chatName;

  const MaterialButtonWidget({
    super.key,
    required this.onPressed,
    required this.chatName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(10),
      child: MaterialButton(
        color: Colors.grey[400],
        hoverColor: Colors.grey[500],
        focusColor: Colors.grey[600],
        splashColor: Colors.black,
        highlightColor: Colors.grey[200],
        minWidth: double.infinity,
        onPressed: onPressed,
        child: Text(chatName, style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
