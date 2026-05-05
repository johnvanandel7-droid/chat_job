import 'package:chat_job/components/section_header.dart';
import 'package:chat_job/screens/view_seller_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:chat_job/components/app_bar.dart';

final firestore = FirebaseFirestore.instance;
final _auth = FirebaseAuth.instance;

class FriendsScreen extends StatefulWidget {
  static const id = 'FriendScreen';

  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<Text> friends = [];
  List<Text> potentialFriends = [];
  bool showSuggestedFriends = false;
  bool showFriends = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(),
      body: Column(
        children: [
          SectionHeader(
            title: 'Companies friended',
            isExpanded: showFriends,
            onToggle: () {
              setState(() {
                showFriends = !showFriends;
              });
            },
          ),

          if (showFriends == true)
            Expanded(child: Text('hi'))
          else
            SizedBox(height: 1),

          SectionHeader(
            title: 'Suggested Companies',
            isExpanded: showSuggestedFriends,
            onToggle: () {
              setState(() {
                showSuggestedFriends = !showSuggestedFriends;
              });
            },
          ),

          if (showSuggestedFriends == true)
            Expanded(child: SuggestedFriendsList())
          else
            SizedBox(height: 1),
        ],
      ),
    );
  }
}

class SuggestedFriendsList extends StatelessWidget {
  const SuggestedFriendsList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('users')
          .where('userId', isNotEqualTo: _auth.currentUser?.uid)
          .orderBy('userId')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print(snapshot.error);
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No other users yet"));
        }

        final docs = snapshot.data!.docs; // already ordered by query
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            final friendEmail =
                (data['userEmail'] as String?)?.trim() ?? 'Unknown';
            final friendId = data['userId'] as String;

            return FriendContactTemplate(
              userEmail: friendEmail,
              userId: friendId,
            );
          },
        );
      },
    );
  }
}

class FriendContactTemplate extends StatelessWidget {
  final String userEmail;
  final String userId;

  const FriendContactTemplate({
    super.key,
    required this.userEmail,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey,
      child: Column(
        children: [
          Text(userEmail.split('@')[0]),
          MaterialButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ViewSellerProfile(
                    sellerId: userId,
                    sellerName: userEmail,
                  ),
                ),
              );
            },
            color: Colors.white54,
            child: Text('view profile'),
          ),
        ],
      ),
    );
  }
}
