import 'package:chat_job/components/app_bar.dart';
import 'package:chat_job/constants.dart';
import 'package:chat_job/screens/view_seller_profile.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final firestore = FirebaseFirestore.instance;
final auth = FirebaseAuth.instance;

class AddTemplate extends StatelessWidget {
  final String addName;
  final String addDescription;
  final dynamic addPrice;
  final String sellerEmail;
  final dynamic quantity;
  final List images;
  final String listingId;
  final String sellerId;

  const AddTemplate({
    super.key,
    required this.sellerEmail,
    required this.addName,
    required this.addDescription,
    required this.addPrice,
    required this.quantity,
    required this.images,
    required this.listingId,
    required this.sellerId,
  });

  Future<void> changeClicksOnListing(BuildContext context) async {
    if (listingId.isEmpty) {
      return;
    }

    try {
      // update both documents
      final batch = firestore.batch();

      batch.set(firestore.collection('listings').doc(listingId), {
        'clicks': FieldValue.increment(1),
      }, SetOptions(merge: true));

      batch.set(firestore.collection('users').doc(sellerId), {
        'clicksOnListing': FieldValue.increment(1),
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update view count'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: () async {
          if (sellerEmail.isEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Invalid seller Id')));
            return;
          }

          await changeClicksOnListing(context);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddTemplateScreen(
                sellerEmail: sellerEmail,
                addName: addName,
                addDescription: addDescription,
                addPrice: addPrice,
                initialQuantity: quantity,
                images: images,
                listingId: listingId,
                sellerId: sellerId,
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text(
                  '$addName for \$$addPrice',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child:
                      images.isNotEmpty &&
                          images[0].toString().trim().isNotEmpty
                      ? Image.network(
                          images[0],
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                height: 120,
                                width: double.infinity,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 50,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 120,
                              width: double.infinity,
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                        )
                      : Container(
                          height: 120,
                          width: double.infinity,
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddTemplateScreen extends StatefulWidget {
  final String addName;
  final String addDescription;
  final double addPrice;
  final String sellerEmail;
  final dynamic initialQuantity;
  final List images;
  final String listingId;
  final String sellerId;

  const AddTemplateScreen({
    super.key,
    required this.sellerEmail,
    required this.addName,
    required this.addDescription,
    required this.addPrice,
    required this.initialQuantity,
    required this.images,
    required this.listingId,
    required this.sellerId,
  });

  @override
  State<AddTemplateScreen> createState() => _AddTemplateScreenState();
}

class _AddTemplateScreenState extends State<AddTemplateScreen> {
  double? lowBall;
  late double currentQuantity;
  String? currentUserEmail;
  String? currentUserUid;

  @override
  void initState() {
    super.initState();
    currentQuantity = (widget.initialQuantity as num?)?.toDouble() ?? 0.0;
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

  Future<void> calculateLowBall(BuildContext context) async {
    if (lowBall == null || lowBall! <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Enter a valid price')));
      return;
    }

    if (lowBall! < widget.addPrice * 0.80) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.grey[600],
          content: Text('Low ball is too low'),
        ),
      );
      return;
    }

    if (currentQuantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.grey[600],
          content: Text('No Stock Available'),
        ),
      );
    }

    // Success put an offer in
    try {
      // save the offer
      await firestore.collection('offers').add({
        'listingId': widget.listingId,
        'buyerId': currentUserUid,
        'buyerEmail': currentUserEmail,
        'sellerId': widget.sellerId,
        'sellerEmail': widget.sellerEmail,
        'offerPrice': lowBall,
        'originalPrice': widget.addPrice,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'title': widget.addName,
        'image': widget.images.isNotEmpty ? widget.images.first : null,
      });

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.grey[600],
          content: Text('You have offered $lowBall for a ${widget.addName}'),
        ),
      );

      // ignore: use_build_context_synchronously
      Navigator.pop(context);
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('$e')),
      );
    }
  }

  Future<void> buyListing() async {
    bool localIsPickup = false;
    String shippingAddress = '';

    // create popup to confirm purchase
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Purchase', style: TextStyle(fontSize: 22)),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose Delivery Method:'),
                const SizedBox(height: 12),
                ToggleButtons(
                  isSelected: [localIsPickup, !localIsPickup],
                  onPressed: (index) {
                    setDialogState(() {
                      localIsPickup = index == 0; // 0 = Pickup, 1 = Shipping
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  selectedColor: Colors.white,
                  fillColor: Colors.blueAccent,
                  color: Colors.grey[700],
                  selectedBorderColor: Colors.blueAccent,
                  borderColor: Colors.grey,
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    minWidth: 100,
                  ),
                  children: const [
                    Text("Pickup", style: TextStyle(fontSize: 16)),
                    Text("Shipping", style: TextStyle(fontSize: 16)),
                  ],
                ),
                if (localIsPickup == false) ...[
                  const Text('shipping address'),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      decoration: kInputDecoration2,
                      onChanged: (newAddress) {
                        setState(() {
                          shippingAddress = newAddress;
                        });
                      },
                    ),
                  ),
                ],
                if (localIsPickup == true) SizedBox(height: 1),
              ],
            );
          },
        ),
        actions: [
          // cancel buy
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),

          // confirm purchase
          MaterialButton(
            color: Colors.green,
            textColor: Colors.white,
            onPressed: () async {
              Navigator.pop(dialogContext);

              await _processPurchase(localIsPickup, shippingAddress);
            },
            child: const Text('Confirm Purchase'),
          ),
        ],
      ),
    );
  }

  Future<void> _processPurchase(
    bool isPickupSelected,
    String shippingAddress,
  ) async {
    if (currentUserUid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You must be logged in')));
      return;
    }

    try {
      final docRef = firestore.collection('listings').doc(widget.listingId);

      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) throw Exception('Listing does not exist');

        final data = snapshot.data()!;
        final int currentStock = (data['quantity'] as num?)?.toInt() ?? 0;

        if (currentStock <= 0) throw Exception('Out of stock');

        // Reduce stock
        transaction.update(docRef, {'quantity': currentStock - 1});

        // Create order with delivery method
        final orderRef = firestore.collection('orders').doc();
        transaction.set(orderRef, {
          'listingId': widget.listingId,
          'buyerId': currentUserUid,
          'buyerEmail': currentUserEmail,
          'sellerId': widget.sellerId,
          'sellerEmail': widget.sellerEmail,
          'price': widget.addPrice,
          'deliveryMethod': isPickupSelected
              ? 'pickup'
              : 'shipping', // ← Saved here
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'ordered',
          'title': widget.addName,
          'image': widget.images.isNotEmpty ? widget.images.first : null,
          'shippingAddress': shippingAddress,
        });

        // update seller information
        await firestore.collection('users').doc(currentUserUid).set({
          'totalCash': FieldValue.increment(-widget.addPrice),
        }, SetOptions(merge: true));
      });

      await firestore.collection('users').doc(widget.sellerId).set({
        'totalCash': FieldValue.increment(widget.addPrice),
        'totalEarnings': FieldValue.increment(widget.addPrice),
        'listingsSold': FieldValue.increment(1),
      }, SetOptions(merge: true));

      // Update local UI
      if (mounted) {
        setState(() {
          currentQuantity -= 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase successful!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // safe seller name
    final String sellerDisplayName = (widget.sellerEmail.isNotEmpty)
        ? widget.sellerEmail.split('@')[0]
        : 'Unknown Seller';

    return Scaffold(
      appBar: AppBarWidget(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                widget.addName,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              color: Colors.grey[400],
              height: 200,
              child: widget.images.isNotEmpty
                  ? ListView(
                      scrollDirection: Axis.horizontal,
                      children: widget.images.map((url) {
                        if (url == null || url.toString().trim().isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(Icons.image_not_supported, size: 80),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.all(10),
                          child: Image.network(
                            url.toString(),
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image, size: 80),
                          ),
                        );
                      }).toList(),
                    )
                  : const Center(
                      child: Icon(Icons.image_not_supported, size: 80),
                    ),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(onPressed: () {}, icon: Icon(Icons.save)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                widget.addDescription,
                style: TextStyle(fontSize: 20),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Price: \$${widget.addPrice}',
                style: TextStyle(fontSize: 20),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                currentQuantity > 0
                    ? 'In stock: $currentQuantity'
                    : 'OUT OF STOCK',
                style: TextStyle(
                  fontSize: 20,
                  color: currentQuantity > 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // View Seller profile button
            Padding(
              padding: EdgeInsets.all(20),
              child: MaterialButton(
                color: Colors.grey[500],
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ViewSellerProfile(
                        sellerName: widget.sellerEmail,
                        sellerId: widget.sellerId,
                      ),
                    ),
                  );
                },
                child: Text(
                  'View $sellerDisplayName company',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Container(
                padding: EdgeInsets.all(20),
                color: Colors.grey[300],
                child: Column(
                  children: [
                    Text('Buy Listing', style: TextStyle(fontSize: 20)),
                    SizedBox(height: 10),
                    MaterialButton(
                      color: Colors.grey[500],
                      onPressed: currentQuantity <= 0
                          ? null
                          : () {
                              buyListing();
                            },
                      child: Text('Pay in full'),
                    ),
                    Row(
                      children: [
                        Text('Low Ball'),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: TextField(
                              keyboardType: TextInputType.numberWithOptions(),
                              onChanged: (value) {
                                lowBall = double.tryParse(value);
                              },
                              decoration: kInputDecoration3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    MaterialButton(
                      color: Colors.grey[500],
                      onPressed: () {
                        calculateLowBall(context);
                      },
                      child: Text('Make An Offer'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
