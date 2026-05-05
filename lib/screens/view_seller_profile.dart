import 'package:chat_job/components/app_bar.dart';
import 'package:chat_job/components/star_rating.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ViewSellerProfile extends StatefulWidget {
  final String sellerId;
  final String sellerName;

  const ViewSellerProfile({
    super.key,
    required this.sellerId,
    required this.sellerName,
  });

  @override
  State<ViewSellerProfile> createState() => _ViewSellerProfileState();
}

class _ViewSellerProfileState extends State<ViewSellerProfile> {
  final firestore = FirebaseFirestore.instance;
  bool showReviews = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                widget.sellerName.split('@')[0],
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
            ),

            // Average Rating with reviews
            StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('seller_ratings')
                  .where('sellerId', isEqualTo: widget.sellerId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(30),
                    child: Text(
                      'No ratings yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                // Calculate average manually (this is reliable)
                double total = 0;
                final docs = snapshot.data!.docs;
                final List<String> ratingMessages = [];
                final List<String> raterNames = [];
                final List<double> rates = [];
                final List<String> rateTime = [];

                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;

                  final rating = (data['rating'] as num?)?.toDouble() ?? 0;
                  final ratingMessage =
                      (data['rating_message'] as String?)?.trim() ?? '';
                  final rater = data['raterId'] as String;

                  // Safe handling for createdAt
                  String formattedTime = 'Unknown date';
                  if (data['createdAt'] is Timestamp) {
                    final timeStamp = data['createdAt'] as Timestamp;
                    formattedTime = timeStamp.toDate().toString().substring(
                      0,
                      7,
                    );
                  } else if (data['createdAt'] != null) {
                    formattedTime = data['createdAt'].toString().substring(
                      0,
                      7,
                    );
                  }

                  total += rating;

                  if (ratingMessage.isNotEmpty && rater.isNotEmpty) {
                    ratingMessages.add(ratingMessage);
                    raterNames.add(rater);
                    rates.add(rating);
                    rateTime.add(formattedTime);
                  }
                }

                final double averageRating = total / docs.length;

                return Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // average rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            averageRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 16),
                          ReusableStarRating(
                            rating: averageRating,
                            starSize: 32,
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        '${docs.length} ratings',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 30),

                      // rating Messages with reviews
                      Row(
                        children: [
                          Expanded(child: SizedBox()),
                          const Text(
                            'Reviews',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                showReviews = !showReviews;
                              });
                            },
                            icon: Icon(
                              showReviews == false
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                            ),
                          ),
                          Expanded(child: SizedBox()),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (showReviews == false)
                        const SizedBox(height: 10)
                      else if (ratingMessages.isEmpty)
                        const Text('No written reviews yet')
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: ratingMessages.length,
                          itemBuilder: (context, index) {
                            return Card(
                              color: Colors.grey[200],
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Rated by: ${raterNames[index].split('@')[0]}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          rateTime[index],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
                                      child: ReusableStarRating(
                                        rating: rates[index],
                                        starSize: 20,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(14),
                                      child: Text(
                                        ratingMessages[index],
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
