import 'package:flutter/material.dart';
import 'package:chat_job/components/app_bar.dart';
import 'package:chat_job/screens/chat.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateChatScreen extends StatefulWidget {
  static const id = 'create_chat_screen';
  const CreateChatScreen({super.key});

  @override
  State<CreateChatScreen> createState() => _CreateChatScreenState();
}

class _CreateChatScreenState extends State<CreateChatScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final List<String> participantIds = [];
  final List<String> participantEmails = [];
  bool isLoading = false;

  @override
  initState() {
    super.initState();

    // automatically add the current user
    final currentUserEmail = _auth.currentUser?.email?.trim();
    final currentUserUid = _auth.currentUser?.uid;
    if (currentUserUid != null && currentUserEmail != null) {
      participantIds.add(currentUserUid);
      participantEmails.add(currentUserEmail);
    }
  }

  Future<String> getUidFromEmail(String email) async {
    final query = await _firestore
        .collection('users')
        .where('userEmail', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return '';

    return query.docs.first.id; // or field depending on your structure
  }

  void addUser() async {
    final email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty) return;

    final uid = await getUidFromEmail(email);

    if (uid == '') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('User not found')),
      );
      return;
    }

    if (participantIds.contains(uid)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('User already added')));
      return;
    }

    setState(() {
      participantIds.add(uid);
      participantEmails.add(email);
      _emailController.clear();
    });
  }

  Future<void> createChat() async {
    if (participantIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one other user')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final chatRef = _firestore.collection('chats').doc();
      final messegesRef = _firestore
          .collection('chats')
          .doc(chatRef.id)
          .collection('messages')
          .doc();

      await chatRef.set({
        'chatName': _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : 'Group Chat',
        'participantIds': participantIds,
        'participantEmails': participantEmails,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': '',
        'isGroup': true, // Helpful flag
        'createdBy': _auth.currentUser?.uid,
      });

      await messegesRef.set({
        'text': 'chat created',
        'senderId': _auth.currentUser!.uid,
        'senderEmail': _auth.currentUser!.email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatRef.id,
              otherUserName: _nameController.text.trim().isNotEmpty
                  ? _nameController.text.trim()
                  : 'Group Chat (${participantIds.length} members)',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create group: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(
                'Start New Chat',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 30),

              // Chat Name
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Enter chat name',
                  hintText: 'Family chat',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),

              // add user email
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Add User Email',
                        hintText: 'example@email.com',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => addUser(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(onPressed: addUser, child: const Text('Add')),
                ],
              ),

              SizedBox(height: 5),

              // List of added users
              Text(
                'Participants',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              participantEmails.isEmpty
                  ? const Center(child: Text('No added users'))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: participantEmails.length,
                      itemBuilder: (context, index) {
                        final uid = participantIds[index];
                        final isCurrentUser =
                            uid == _auth.currentUser?.uid.trim();
                        final email = participantEmails[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(email),
                          subtitle: isCurrentUser ? const Text('(You)') : null,
                          trailing: isCurrentUser
                              ? null
                              : IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      participantIds.removeAt(index);
                                      participantEmails.removeAt(index);
                                    });
                                  },
                                ),
                        );
                      },
                    ),
              SizedBox(height: 20),

              // Create Chat button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : createChat,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'create chat',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Note: Enter the exact email of the buyer or seller',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
