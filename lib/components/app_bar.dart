import 'package:chat_job/screens/buy_sell_screen.dart';
import 'package:chat_job/screens/chat_job_home.dart';
import 'package:chat_job/screens/chats_screen.dart';
import 'package:chat_job/screens/friends_screen.dart';
import 'package:chat_job/screens/my_company_screen.dart';
import 'package:chat_job/screens/notifications_screen.dart';
import 'package:chat_job/screens/welcome_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'reusable_icon_button.dart';

final _firestore = FirebaseFirestore.instance;
final _auth = FirebaseAuth.instance;

class AppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  const AppBarWidget({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(80);

  Stream<int>? getUnreadCount() {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      return const Stream.empty();
    }

    try {
      return _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: uid)
          .where('read', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    } catch (e) {
      print('error: $e');
      return const Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 10,
      backgroundColor: Colors.grey[600],
      centerTitle: true,
      automaticallyImplyLeading: false,
      title: Text(
        'Chat Job',
        style: TextStyle(fontSize: 20, color: Colors.black),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(30),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ReusableIconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: Icon(Icons.arrow_back),
              ),
              ReusableIconButton(
                onPressed: () {
                  Navigator.pushNamed(context, ChatsScreen.id);
                },
                icon: Icon(Icons.chat),
              ),
              ReusableIconButton(
                onPressed: () {
                  Navigator.pushNamed(context, MyCompany.id);
                },
                icon: Icon(Icons.person),
              ),
              ReusableIconButton(
                onPressed: () {
                  Navigator.pushNamed(context, ChatJobHome.id);
                },
                icon: Icon(Icons.home),
              ),
              ReusableIconButton(
                onPressed: () {
                  Navigator.pushNamed(context, BuySellScreen.id);
                },
                icon: Icon(Icons.sell),
              ),
              ReusableIconButton(
                onPressed: () {
                  Navigator.pushNamed(context, FriendsScreen.id);
                },
                icon: Icon(Icons.person_add),
              ),
              StreamBuilder<int>(
                stream: getUnreadCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;

                  return Stack(
                    children: [
                      ReusableIconButton(
                        onPressed: () {
                          Navigator.pushNamed(context, NotificationsScreen.id);
                        },
                        icon: Icon(Icons.notifications),
                      ),

                      if (count > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Center(
                              child: Text(
                                count > 9 ? '9+' : '$count',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              ReusableIconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  _auth.signOut();
                  Navigator.pushNamed(context, WelcomeScreen.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
