import 'package:chat_job/screens/sell_history.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:chat_job/screens/edit_listing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_job/components/app_bar.dart';

class MyAddsList extends StatefulWidget {
  static const id = 'my_adds_list';

  const MyAddsList({super.key});

  @override
  State<MyAddsList> createState() => _MyAddsListState();
}

class _MyAddsListState extends State<MyAddsList> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final String currentUserEmail = _auth.currentUser.toString();
    final String currentUserUid = _auth.currentUser!.uid.toString();

    if (currentUserEmail.isEmpty) {
      return Scaffold(
        appBar: AppBarWidget(),
        body: Center(child: Text('User invalid Try logging in')),
      );
    }
    return Scaffold(
      appBar: AppBarWidget(),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('listings')
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
            return const Center(child: Text("No Listings yet"));
          }

          final docs = snapshot.data!.docs; // already ordered by query

          List<MyAddTemplate> adds = [];

          for (var doc in docs) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] as String? ?? '(no text)';
              final description = data['description'] as String? ?? '(unknown)';
              final price = data['price'] as num? ?? 0;
              final quantity = data['quantity'] ?? 0;
              final images = List<String>.from(data['images'] ?? []);
              final clicksOnListing = data['clicks'] ?? 0.0;

              adds.add(
                MyAddTemplate(
                  id: doc.id,
                  addName: title,
                  addDescription: description,
                  addPrice: price,
                  quantity: quantity,
                  images: images,
                  clicksOnListing: clicksOnListing,
                ),
              );
            } catch (e) {
              print(e);
              return Center(child: Text('Error parcing message ${doc.id}: $e'));
            }
          }

          return ListView(
            reverse: false,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
            children: adds,
          );
        },
      ),
    );
  }
}

class MyAddTemplate extends StatelessWidget {
  final String addName;
  final String addDescription;
  final dynamic addPrice;
  final String id;
  final dynamic quantity;
  final List images;
  final int clicksOnListing;

  const MyAddTemplate({
    super.key,
    required this.id,
    required this.addName,
    required this.addDescription,
    required this.addPrice,
    required this.quantity,
    required this.images,
    required this.clicksOnListing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyAddTemplateScreen(
                id: id,
                addName: addName,
                addDescription: addDescription,
                addPrice: addPrice,
                quantity: quantity,
                images: images,
                clicksOnListing: clicksOnListing,
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
                  '$addName for \$${addPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  addDescription,
                  style: TextStyle(color: Colors.black, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyAddTemplateScreen extends StatelessWidget {
  final String addName;
  final String addDescription;
  final dynamic addPrice;
  final String id;
  final dynamic quantity;
  final List images;
  final int clicksOnListing;

  const MyAddTemplateScreen({
    super.key,
    required this.id,
    required this.addName,
    required this.addDescription,
    required this.addPrice,
    required this.quantity,
    required this.images,
    required this.clicksOnListing,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                addName,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
            ),
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: MaterialButton(
                    color: Colors.grey[500],
                    onPressed: () async {
                      final confirm = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text("Delete Listing"),
                          content: Text(
                            "Are you sure you want to delete this?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text("Delete"),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          // optional delete all the listings images
                          final doc = await firestore
                              .collection('listings')
                              .doc(id)
                              .get();
                          final imageUrls = List<String>.from(
                            doc.data()?['images'] ?? [],
                          );

                          for (var url in imageUrls) {
                            try {
                              final ref = FirebaseStorage.instance.refFromURL(
                                url,
                              );
                              await ref.delete();
                            } catch (_) {}
                          }

                          await FirebaseFirestore.instance
                              .collection('listings')
                              .doc(id)
                              .delete();

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Listing deleted successfully'),
                            ),
                          );
                          Navigator.pop(context); // go back to list
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to delete: $e')),
                          );
                        }
                      }
                    },
                    child: Text('Delete Listing'),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(10),
                  child: MaterialButton(
                    color: Colors.grey[500],
                    onPressed: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditListing(
                            listingId: id,
                            title: addName,
                            description: addDescription,
                            price: addPrice,
                            images: images,
                            quantity: quantity,
                          ),
                        ),
                      );

                      if (updated == true) {
                        Navigator.pop(context);
                      }
                    },
                    child: Text('Edit Listing'),
                  ),
                ),
              ],
            ),
            Container(
              color: Colors.grey[400],
              height: 200,
              child: images.isNotEmpty
                  ? ListView(
                      scrollDirection: Axis.horizontal,
                      children: images.map((url) {
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
              child: Text(addDescription, style: TextStyle(fontSize: 20)),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Text('\$$addPrice', style: TextStyle(fontSize: 20)),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Quantity: $quantity',
                style: TextStyle(fontSize: 20),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Clicks on listing: $clicksOnListing',
                style: TextStyle(fontSize: 20),
              ),
            ),
            SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
