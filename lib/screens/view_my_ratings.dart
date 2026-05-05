import 'package:chat_job/components/app_bar.dart';
import 'package:chat_job/components/star_rating.dart';
import 'package:chat_job/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _firestore = FirebaseFirestore.instance;
final _auth = FirebaseAuth.instance;

class ViewMyRatings extends StatelessWidget {
  static const id = 'view_my_rating';
  const ViewMyRatings({super.key});

  @override
  Widget build(BuildContext context) {
    String currentUserUid = _auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBarWidget(),
      body: Column(
        children: [
          Text('My ratings', style: TextStyle(fontSize: 20)),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('seller_ratings')
                  .where('sellerId', isEqualTo: currentUserUid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No ratings yet!"));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final rating = data['rating'] as num;
                    final ratingMessage = data['rating_message'] as String;
                    final raterEmail = data['raterEmail'] as String;

                    return ReviewContainerTemplate(
                      rating: rating.toDouble(),
                      raterEmail: raterEmail,
                      ratingMessage: ratingMessage,
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

class ReviewContainerTemplate extends StatelessWidget {
  final double rating;
  final String ratingMessage;
  final String raterEmail;

  const ReviewContainerTemplate({
    super.key,
    required this.rating,
    required this.raterEmail,
    required this.ratingMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: kContainerDecoration,
      child: Column(
        children: [
          Text(raterEmail, style: TextStyle(color: Colors.grey)),
          ReusableStarRating(rating: rating, starSize: 10),
          SizedBox(height: 10),
          Text(ratingMessage),
        ],
      ),
    );
  }
}
