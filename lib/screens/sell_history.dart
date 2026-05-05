import 'package:chat_job/components/add_template.dart';
import 'package:chat_job/components/app_bar.dart';
import 'package:chat_job/components/section_header.dart';
import 'package:chat_job/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_job/components/time_ago.dart';

final firestore = FirebaseFirestore.instance;
final auth = FirebaseAuth.instance;
//final _messaging = FirebaseMessaging.instance;

class SellHistory extends StatefulWidget {
  static const id = 'sell_history';
  const SellHistory({super.key});

  @override
  State<SellHistory> createState() => _SellHistoryState();
}

class _SellHistoryState extends State<SellHistory> {
  String? currentUserEmail;
  String? currentUserUid;
  bool showOrders = false;
  bool showOffers = false;

  @override
  void initState() {
    super.initState();
    getCurrentUser();
  }

  void getCurrentUser() {
    final user = auth.currentUser;
    if (user != null && user.email != null) {
      setState(() {
        currentUserEmail = user.email!
            .trim()
            .toLowerCase(); // Use full email, lowercase for safety
        currentUserUid = user.uid;
      });
    } else {
      setState(() {
        currentUserEmail = null;
        currentUserUid = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserEmail == null || currentUserUid == null) {
      return Scaffold(
        appBar: AppBarWidget(),
        body: const Center(child: Text('please log in to view sell history')),
      );
    }

    return Scaffold(
      appBar: AppBarWidget(),
      body: Column(
        children: [
          Text(
            'My Selling',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          SectionHeader(
            title: 'Orders',
            isExpanded: showOrders,
            onToggle: () {
              setState(() {
                showOrders = !showOrders;
                if (showOrders) {
                  showOffers = false;
                }
              });
            },
          ),
          if (showOrders)
            Expanded(child: OrdersList(currentUserUid: currentUserUid!))
          else
            SizedBox(height: 1),

          SectionHeader(
            title: 'Offers',
            isExpanded: showOffers,
            onToggle: () {
              setState(() {
                showOffers = !showOffers;
                if (showOffers) {
                  showOrders = false;
                }
              });
            },
          ),

          if (showOffers)
            Expanded(child: MyOffersList(currentUserUid: currentUserUid!))
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class OrdersList extends StatelessWidget {
  final String currentUserUid;

  const OrdersList({super.key, required this.currentUserUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('orders')
          .where('sellerId', isEqualTo: currentUserUid)
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
          return const Center(child: Text("No selling history yet"));
        }

        final docs = snapshot.data!.docs; // already ordered by query

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            final buyerEmail =
                (data['buyerEmail'] as String?)?.trim() ?? 'Unknown';
            final buyerId = data['buyerId'] as String;
            final status = data['status'] as String? ?? 'pending';
            final createdAt = data['createdAt'];
            final listingId = data['listingId'];
            final firstImage = data['image'];

            final timeAgo = createdAt is Timestamp
                ? formatTimeAgo(createdAt)
                : 'Just now';

            return SellerContactsTemplate(
              buyerEmail: buyerEmail,
              boughtTime: timeAgo,
              offerStatus: status,
              isOffer: false,
              offerId: docs[index].id,
              offerPrice: 0,
              listingId: listingId,
              buyerId: buyerId,
              firstImage: firstImage,
            );
          },
        );
      },
    );
  }
}

class MyOffersList extends StatelessWidget {
  final String currentUserUid;

  const MyOffersList({super.key, required this.currentUserUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('offers')
          .where('buyerId', isEqualTo: currentUserUid)
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
          return const Center(child: Text("No Listings yet"));
        }

        final docs = snapshot.data!.docs; // already ordered by query
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            final buyerEmail =
                (data['buyerEmail'] as String?)?.trim() ?? 'Unknown';
            final buyerId = data['buyerId'] as String;
            final status = data['status'] as String? ?? 'pending';
            final createdAt = data['createdAt'];
            final offerPrice = data['offerPrice'];
            final listingId = data['listingId'];
            final firstImage = data['image'] ?? '';

            final timeAgo = createdAt is Timestamp
                ? formatTimeAgo(createdAt)
                : 'Just now';

            return SellerContactsTemplate(
              buyerEmail: buyerEmail,
              boughtTime: timeAgo,
              offerStatus: status,
              isOffer: true,
              offerId: docs[index].id,
              offerPrice: offerPrice.toDouble(),
              listingId: listingId,
              buyerId: buyerId,
              firstImage: firstImage,
            );
          },
        );
      },
    );
  }
}

class SellerContactsTemplate extends StatefulWidget {
  final String buyerEmail;
  final String buyerId;
  final String boughtTime;
  final String offerStatus;
  final String offerId;
  final bool isOffer;
  final double offerPrice;
  final String listingId;
  final String firstImage;

  const SellerContactsTemplate({
    super.key,
    required this.boughtTime,
    required this.buyerEmail,
    required this.offerStatus,
    required this.isOffer,
    required this.offerId,
    required this.offerPrice,
    required this.listingId,
    required this.buyerId,
    required this.firstImage,
  });

  @override
  State<SellerContactsTemplate> createState() => _SellerContactsTemplateState();
}

class _SellerContactsTemplateState extends State<SellerContactsTemplate> {
  bool showLargeContact = false;
  String counterOffer = '';
  String cancelReason = '';

  Future<Map<String, dynamic>?> getListingInfo(String listingId) async {
    try {
      final DocumentSnapshot document = await firestore
          .collection('listings')
          .doc(listingId)
          .get();

      if (!document.exists) {
        return null;
      }

      final docs = document.data() as Map<String, dynamic>;

      return {
        'title': docs['title'] as String? ?? 'Untitled Listing',
        'description': docs['description'] as String? ?? '',
        'price': docs['price'] as num? ?? 0.0,
        'quantity': docs['quantity'] ?? 0,
        'images': List<String>.from(docs['images'] ?? []),
        'sellerId': docs['sellerId'] as String? ?? '',
        'sellerEmail': docs['sellerEmail'] as String,
        'createdAt': docs['createdAt'],
      };
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(5),
      child: GestureDetector(
        onTap: () {
          setState(() {
            showLargeContact = !showLargeContact;
          });
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          height: showLargeContact == false ? 60 : 370,
          padding: EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.grey,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              // allways visible content
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FutureBuilder<Map<String, dynamic>?>(
                    future: getListingInfo(widget.listingId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.grey,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data == null) {
                        return const CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.grey,
                          child: Icon(Icons.image_not_supported, size: 20),
                        );
                      }

                      final listingData = snapshot.data!;
                      final images = listingData['images'] as List<String>;

                      final firstImageUrl = images.isNotEmpty
                          ? images.first
                          : null;

                      return CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.grey[700],
                        backgroundImage:
                            firstImageUrl != null && firstImageUrl.isNotEmpty
                            ? NetworkImage(firstImageUrl)
                            : NetworkImage(widget.firstImage),
                        child: firstImageUrl == null || firstImageUrl.isEmpty
                            ? const Icon(Icons.image_not_supported, size: 20)
                            : null,
                      );
                    },
                  ),
                  Text(
                    widget.buyerEmail.contains('@')
                        ? widget.buyerEmail.split('@')[0]
                        : widget.buyerEmail,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(widget.boughtTime, style: const TextStyle(fontSize: 12)),
                ],
              ),

              // expanded content
              if (showLargeContact)
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>?>(
                    future: getListingInfo(widget.listingId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError || snapshot.data == null) {
                        return const Center(
                          child: Text('Failed to load listing details'),
                        );
                      }

                      final listingData = snapshot.data!;

                      return Column(
                        children: [
                          const SizedBox(height: 10),

                          // clickable listing card
                          GestureDetector(
                            onTap: () async {
                              // ignore: use_build_context_synchronously
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddTemplateScreen(
                                    sellerEmail: listingData['sellerEmail'],
                                    addName: listingData['title'],
                                    addDescription: listingData['description'],
                                    addPrice: listingData['price'],
                                    initialQuantity: listingData['quantity'],
                                    images: listingData['images'],
                                    listingId: widget.listingId,
                                    sellerId: listingData['sellerId'],
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Text('\$${listingData['price']}'),
                                  Spacer(),
                                  Text(listingData['title']),
                                  Spacer(),
                                  Text('View listing'),
                                  Spacer(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.isOffer ? 'Offer Status' : 'Order Status',
                            style: const TextStyle(fontWeight: FontWeight.w300),
                          ),
                          Text(
                            widget.offerStatus.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (widget.isOffer)
                            Column(
                              children: [
                                Text('Offer \$${widget.offerPrice}'),
                                Row(
                                  children: [
                                    Spacer(),
                                    MaterialButton(
                                      color: Colors.red[400],
                                      onPressed: () async {
                                        try {
                                          await firestore
                                              .collection('offers')
                                              .doc(widget.offerId)
                                              .update({'status': 'declined'});
                                        } catch (e) {
                                          debugPrint('Decline failed: $e');
                                        }
                                      },
                                      child: const Text(
                                        'Decline Offer',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    SizedBox(width: 20),
                                    MaterialButton(
                                      onPressed: () async {
                                        await firestore
                                            .collection('offers')
                                            .doc(widget.offerId)
                                            .update({'status': 'confirmed'});
                                      },
                                      color: Colors.green,
                                      child: Text(
                                        'Confirm Offer',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    Spacer(),
                                  ],
                                ),
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.grey[600],
                                  ),
                                  child: Column(
                                    children: [
                                      TextField(
                                        decoration: kInputDecoration2,
                                        onChanged: (newText) {
                                          counterOffer = newText;
                                        },
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          await firestore
                                              .collection('offers')
                                              .doc(widget.offerId)
                                              .update({
                                                'status': 'counterOffer',
                                                'counterOffer': counterOffer,
                                              });
                                        },
                                        child: Text(
                                          'Confirm counter offer',
                                          style: TextStyle(color: Colors.black),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else if (widget.isOffer == false)
                            MaterialButton(
                              onPressed: () async {
                                await showDialog(
                                  context: context,
                                  builder: (dialogContext) => StatefulBuilder(
                                    builder: (context, setDialogState) {
                                      return AlertDialog(
                                        title: Text('Cancel order'),
                                        constraints: BoxConstraints(
                                          maxHeight: 400,
                                        ),
                                        content: Column(
                                          children: [
                                            TextField(
                                              decoration: InputDecoration(
                                                hintText: 'out of stock',
                                                hintStyle: TextStyle(
                                                  color: Colors.grey,
                                                ),
                                                helperText:
                                                    'Why are you canceling this order',
                                                border: OutlineInputBorder(),
                                              ),
                                              onChanged: (newText) {
                                                cancelReason = newText;
                                              },
                                            ),
                                            SizedBox(height: 30),
                                            Text(
                                              'If you cancel this order it will be immediatly refunded and your seller points will go down.',
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          MaterialButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: Text('Cancel'),
                                          ),
                                          MaterialButton(
                                            color: Colors.red,
                                            onPressed: () async {
                                              await firestore
                                                  .collection('orders')
                                                  .doc(widget.offerId)
                                                  .update({
                                                    'status': 'cancelled',
                                                  });

                                              Navigator.pop(context);
                                            },
                                            child: Text('Delete Order'),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                );
                              },
                              color: Colors.red,
                              child: Text('Delete order'),
                            )
                          else
                            Text('This is not a normal order'),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
