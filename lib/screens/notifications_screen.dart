import 'package:chat_job/components/app_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:chat_job/components/time_ago.dart';

final firestore = FirebaseFirestore.instance;
final auth = FirebaseAuth.instance;

class NotificationsScreen extends StatelessWidget {
  static const id = 'notifications';

  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserUid = auth.currentUser?.uid;

    if (currentUserUid == null) {
      return const Scaffold(body: Center(child: Text("Please log in")));
    }

    return Scaffold(
      appBar: AppBarWidget(),
      body: Column(
        children: [
          Row(
            children: [
              Spacer(),
              Text('Delete all', style: TextStyle(fontSize: 20)),
              IconButton(
                onPressed: () async {
                  try {
                    final docs = await firestore
                        .collection('notifications')
                        .where('receiverId', isEqualTo: currentUserUid)
                        .get();
                    final batch = firestore.batch();

                    for (var doc in docs.docs) {
                      batch.delete(doc.reference);
                    }
                    await batch.commit();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error deleteing notifications $e'),
                      ),
                    );
                  }
                },
                icon: Icon(Icons.delete),
              ),
              Spacer(),
              Text('Read all', style: TextStyle(fontSize: 20)),
              SizedBox(width: 10),
              IconButton(
                icon: Icon(Icons.done_all),
                onPressed: () async {
                  final docs = await firestore
                      .collection('notifications')
                      .where('receiverId', isEqualTo: currentUserUid)
                      .where('read', isEqualTo: false)
                      .get();
                  final batch = firestore.batch();

                  for (var doc in docs.docs) {
                    batch.update(doc.reference, {'read': true});
                  }
                  await batch.commit();
                },
              ),
              Spacer(),
            ],
          ),
          Expanded(
            child: StreamBuilder(
              stream: firestore
                  .collection('notifications')
                  .where('receiverId', isEqualTo: currentUserUid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  print(snapshot.error);
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text('No notifications yet'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    // ignore: unnecessary_cast
                    final data = docs[index].data() as Map<String, dynamic>;
                    final title = data['title'] as String? ?? 'Notification';

                    final message = data['message'] as String? ?? '';
                    final createdAt = data['createdAt'] as Timestamp?;
                    final isRead = data['read'] as bool? ?? false;
                    final screen = data['screen'] as String?;
                    final relatedId = data['relatedId'] as String?;

                    final type = data['type'] as String? ?? '';

                    return NotificationTile(
                      id: docs[index].id,
                      title: title,
                      message: message,
                      createdAt: createdAt,
                      isRead: isRead,
                      screen: screen,
                      relatedId: relatedId,
                      type: type,
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

class NotificationTile extends StatefulWidget {
  final String id;
  final String title;
  final String message;
  final Timestamp? createdAt;
  final bool isRead;
  final String? screen;
  final String? relatedId;
  final String type;

  const NotificationTile({
    super.key,
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    this.screen,
    this.relatedId,
    required this.type,
  });

  @override
  State<NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<NotificationTile> {
  Future<void> markAsRead() async {
    try {
      await firestore.collection('notifications').doc(widget.id).update({
        'read': true,
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error marking as read $e')));
    }
  }

  void handleNavigation(BuildContext context) {
    if (widget.screen == "orders") {
      Navigator.pushNamed(context, '/orders');
    } else if (widget.screen == "offers") {
      Navigator.pushNamed(context, '/offers');
    } else if (widget.screen == "profile") {
      Navigator.pushNamed(context, '/profile');
    }
  }

  IconData getIcon(String type) {
    switch (type) {
      case 'offer':
        return Icons.local_offer;
      case 'order':
        return Icons.shopping_cart;
      case 'message':
        return Icons.message;
      case 'offerAccepted':
        return Icons.check_circle;
      case 'offerDeclined':
        return Icons.cancel;
      case 'counterOffer':
        return Icons.swap_horiz;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      // use a unique key
      key: ValueKey(widget.id),

      direction: DismissDirection.startToEnd,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),

      // What to do ondismiss
      confirmDismiss: (direction) async {
        try {
          await Future.delayed(Duration(milliseconds: 100));
          await firestore.collection('notifications').doc(widget.id).delete();
          if (!context.mounted) return false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification dismissed'),
              backgroundColor: Colors.green,
            ),
          );
          return true;
        } catch (e) {
          return false;
        }
      },

      child: InkWell(
        onTap: () async {
          await markAsRead();
          if (!context.mounted) return;
          handleNavigation(context);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(00, 12, 12, 12),
          decoration: BoxDecoration(
            color: widget.isRead ? Colors.white : Colors.blue.withOpacity(0.1),
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              // unread dot
              if (!widget.isRead)
                SizedBox(
                  width: 30,
                  child: Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              if (widget.isRead)
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Icon(getIcon(widget.type), size: 20),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.message),
                    const SizedBox(height: 4),
                    Text(
                      widget.createdAt != null
                          ? formatTimeAgo(widget.createdAt)
                          : 'Just now',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
