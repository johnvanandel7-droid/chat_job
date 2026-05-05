import 'package:chat_job/components/app_bar.dart';
import 'package:chat_job/constants.dart';
import 'package:chat_job/screens/chat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_job/components/section_header.dart';
import 'package:chat_job/components/time_ago.dart';

final firestore = FirebaseFirestore.instance;
final auth = FirebaseAuth.instance;

class MyPurchasesScreen extends StatefulWidget {
  static const id = 'my_purchases_screen';
  const MyPurchasesScreen({super.key});

  @override
  State<MyPurchasesScreen> createState() => _MyPurchasesScreenState();
}

class _MyPurchasesScreenState extends State<MyPurchasesScreen> {
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // check if logged in properly
    if (currentUserEmail == null || currentUserUid == null) {
      return Scaffold(
        appBar: AppBarWidget(),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Loading your purchases..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBarWidget(),
      body: Column(
        children: [
          Text(
            'My Purchases',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),

          // Orders section
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
            Expanded(child: MyOrdersList(currentUserUid: currentUserUid!))
          else
            const SizedBox(height: 10),

          const SizedBox(height: 6),

          // Offers Section
          SectionHeader(
            title: 'Offers',
            isExpanded: showOffers,
            onToggle: () {
              setState(() {
                showOffers = !showOffers;
                if (showOffers) showOrders = false;
              });
            },
          ),
          if (showOffers)
            Expanded(child: MyOffersList(currentUserUid: currentUserUid!)),
        ],
      ),
    );
  }
}

class MyOrdersList extends StatelessWidget {
  final String currentUserUid;

  const MyOrdersList({super.key, required this.currentUserUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('orders')
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
          return const Center(child: Text("No Orders yet"));
        }

        final docs = snapshot.data!.docs; // already ordered by query

        List<BuyerContactsTemplate> orders = [];

        for (var doc in docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;

            // seller Info
            final sellerEmail = data['sellerEmail'] as String? ?? '(no text)';
            final sellerId = data['sellerId'] as String? ?? '';

            // buyer id
            final buyerId = data['buyerId'] as String? ?? '??';

            // order status
            final orderStatus = data['status'];

            // Safe Timestamp handling
            final createdAt = data['createdAt'];

            if (buyerId == currentUserUid) {
              orders.add(
                BuyerContactsTemplate(
                  boughtTime: formatTimeAgo(createdAt),
                  sellerEmail: sellerEmail,
                  raterId: currentUserUid,
                  offerStatus: orderStatus,
                  sellerId: sellerId,
                ),
              );
            }
          } catch (e) {
            return Center(child: Text('error parcing message${doc.id} $e'));
          }
        }

        return ListView(
          reverse: false,
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
          children: orders,
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

        List<BuyerContactsTemplate> offers = [];

        for (var doc in docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;

            // seller Info
            final sellerEmail = data['sellerEmail'] as String? ?? '(no text)';
            final sellerId = data['sellerId'] as String? ?? '';

            // buyer id
            final buyerId = data['buyerId'] as String? ?? '??';

            // offer status
            final offerStatus = data['status'];

            // Safe Timestamp handling
            final createdAt = data['createdAt'];

            if (buyerId == currentUserUid) {
              offers.add(
                BuyerContactsTemplate(
                  offerStatus: offerStatus,
                  boughtTime: formatTimeAgo(createdAt),
                  sellerEmail: sellerEmail,
                  raterId: currentUserUid,
                  sellerId: sellerId,
                ),
              );
            }
          } catch (e) {
            return Center(child: Text('error parcing message${doc.id} $e'));
          }
        }

        return ListView(
          reverse: false,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          children: offers,
        );
      },
    );
  }
}

class BuyerContactsTemplate extends StatefulWidget {
  final String sellerEmail;
  final String sellerId;
  final dynamic boughtTime;
  final String raterId;
  final String offerStatus;

  const BuyerContactsTemplate({
    super.key,
    required this.sellerEmail,
    required this.boughtTime,
    required this.raterId,
    required this.offerStatus,
    required this.sellerId,
  });

  @override
  State<BuyerContactsTemplate> createState() => _BuyerContactsTemplateState();
}

class _BuyerContactsTemplateState extends State<BuyerContactsTemplate> {
  int _rating = 0;
  String _ratingMessage = '';
  bool showLargeContact = false;

  Future<void> rateSeller() async {
    int localRating = _rating;
    String localRatingMessage = _ratingMessage;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // ← Use this for dialog only
          return AlertDialog(
            title: Text(
              'Rate ${widget.sellerEmail.contains('@') ? widget.sellerEmail.split('@')[0] : widget.sellerEmail}',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  // Stars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            // ← Only update dialog
                            localRating = index + 1;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            index < localRating
                                ? Icons.star
                                : Icons.star_border,
                            color: index < localRating
                                ? Colors.amber
                                : Colors.grey,
                            size: 30,
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Why did you rate them this way?',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    maxLength: 200,
                    maxLines: 5,
                    decoration: kInputDecoration2,
                    onChanged: (text) {
                      localRatingMessage = text;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (localRating == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select at least 1 star'),
                      ),
                    );
                    return;
                  }

                  // Update parent state and close dialog
                  setState(() {
                    // ← Parent setState
                    _rating = localRating;
                    _ratingMessage = localRatingMessage;
                  });

                  Navigator.pop(dialogContext);
                  _saveRatingToFirebase();
                },
                child: const Text(
                  'Submit Rating',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveRatingToFirebase() async {
    try {
      await firestore.collection('seller_ratings').add({
        'raterId': widget.raterId,
        'sellerEmail': widget.sellerEmail,
        'sellerId': widget.sellerId,
        'rating': _rating,
        'rating_message': _ratingMessage,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your rating!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save rating: $e')));
      }
    }
  }

  Text showStatus() {
    if (widget.offerStatus == 'pending') {
      return Text('awaiting seller confirmation');
    } else if (widget.offerStatus == 'ordered') {
      return Text('getting packaged');
    } else if (widget.offerStatus == 'shipping') {
      return Text('getting shipped');
    } else if (widget.offerStatus == 'declined') {
      return Text('offer declined');
    } else {
      return Text('try re ordering');
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
          height: showLargeContact == true ? 230 : 50,
          padding: EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.grey,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    '${widget.sellerEmail.contains('@') ? widget.sellerEmail.split('@')[0] : widget.sellerEmail} • ${widget.boughtTime.length >= 16 ? widget.boughtTime.substring(0, 16) : widget.boughtTime}',
                  ),
                  SizedBox(width: 20),
                ],
              ),
              if (showLargeContact == true)
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        padding: EdgeInsets.all(10),
                        color: Colors.grey[400],
                        child: showStatus(),
                      ),
                    ),
                    MaterialButton(
                      color: Colors.grey[400],
                      onPressed: () {
                        rateSeller();
                      },
                      child: Text('Rate Seller'),
                    ),
                    MaterialButton(
                      color: Colors.grey[400],
                      onPressed: () async {
                        final currentUser = FirebaseAuth
                            .instance
                            .currentUser
                            ?.email
                            ?.trim()
                            .toLowerCase();
                        if (currentUser == null) return;

                        final participants = [currentUser, widget.sellerEmail]
                          ..sort();
                        final chatId = '${participants[0]}_${participants[1]}';

                        // Create chat if not exists
                        await FirebaseFirestore.instance
                            .collection('chats')
                            .doc(chatId)
                            .set({
                              'chatName': widget.sellerEmail,
                              'participants': participants,
                              'buyerId': currentUser,
                              'sellerId': widget.sellerEmail,
                              'createdAt': FieldValue.serverTimestamp(),
                              'lastMessage': '',
                              'lastMessageTime': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              chatId: chatId,
                              otherUserName: widget.sellerEmail.split('@')[0],
                            ),
                          ),
                        );
                      },
                      child: Text('Contact Seller'),
                    ),
                    MaterialButton(
                      color: Colors.grey[400],
                      onPressed: () {},
                      child: Text('Cancel order'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
