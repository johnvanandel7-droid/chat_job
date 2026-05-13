import 'package:chat_job/components/add_template.dart';
import 'package:chat_job/components/app_bar.dart';
import 'package:chat_job/components/star_rating.dart';
import 'package:chat_job/constants.dart';
import 'package:chat_job/screens/add_money_screen.dart';
import 'package:chat_job/screens/buy_sell_screen.dart';
import 'package:chat_job/screens/create_listing.dart';
import 'package:chat_job/screens/edit_company.dart';
import 'package:chat_job/screens/my_listings_screen.dart';
import 'package:chat_job/screens/my_purchases_screen.dart';
import 'package:chat_job/screens/sell_history.dart';
import 'package:chat_job/screens/view_my_ratings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

List<String> dropDownItems = [
  'today',
  'past week',
  'past month',
  'past 4 months',
  'past year',
];

final _firestore = FirebaseFirestore.instance;

class MyCompany extends StatefulWidget {
  static const id = 'sell_screen';
  const MyCompany({super.key});

  @override
  State<MyCompany> createState() => _MyCompanyState();
}

class _MyCompanyState extends State<MyCompany> {
  String? _companyName;
  final _auth = FirebaseAuth.instance;

  String? userUid;
  String? userEmail;

  int? clicksOnListings;
  double? totalEarnings;
  double? cash;
  double? listingsSold;
  double? averageRating;
  List<String> watchListIds = [];

  String dropDownValue = dropDownItems.first;

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  // Merged getCurrentUser + getSellerInfo + getRating into one init flow.
  // Avoids redundant Firestore reads and repeated setState calls.
  Future<void> _initUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _companyName = 'Not allowed');
      return;
    }

    final uid = user.uid;
    final email = user.email?.trim().toLowerCase() ?? '';

    if (mounted) {
      setState(() {
        userUid = uid;
        userEmail = email;
        _companyName = email.split('@')[0].trim();
      });
    }

    // Run both Firestore reads concurrently instead of sequentially.
    await Future.wait([_loadSellerInfo(uid), _loadAverageRating(uid)]);
  }

  Future<void> _loadSellerInfo(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists || !mounted) return;

      final data = doc.data()!;
      final rawList = data['watchList'];

      setState(() {
        clicksOnListings = (data['clicksOnListing'] as num?)?.toInt() ?? 0;
        totalEarnings = (data['totalEarnings'] as num?)?.toDouble() ?? 0.0;
        cash = (data['totalCash'] as num?)?.toDouble() ?? 0.0;
        listingsSold = (data['listingsSold'] as num?)?.toDouble() ?? 0.0;
        if (rawList is List) {
          watchListIds = List<String>.from(rawList);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load seller info: $e')),
        );
      }
    }
  }

  Future<void> _loadAverageRating(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('seller_ratings')
          .where('sellerId', isEqualTo: uid)
          .get();

      if (!mounted) return;

      if (snapshot.docs.isEmpty) {
        setState(() => averageRating = 0);
        return;
      }

      final total = snapshot.docs.fold<double>(0, (sum, doc) {
        return sum + ((doc.data()['rating'] as num?)?.toDouble() ?? 0);
      });

      setState(() => averageRating = total / snapshot.docs.length);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load ratings')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildButton(
              'Buy',
              () => Navigator.pushNamed(context, BuySellScreen.id),
            ),
            _buildButton(
              'Edit Company',
              () => Navigator.pushNamed(context, EditCompany.id),
            ),
            Text(
              'Company Name',
              style: TextStyle(color: Colors.grey[800], fontSize: 15),
            ),
            Text(
              _companyName ?? 'Not Logged In',
              style: const TextStyle(color: Colors.black, fontSize: 30),
            ),
            _buildButton(
              'Create Listing',
              () => Navigator.pushNamed(context, CreateListing.id),
            ),
            _buildButton(
              'My Listings',
              () => Navigator.pushNamed(context, MyAddsList.id),
            ),
            _buildButton(
              'My Purchases',
              () => Navigator.pushNamed(context, MyPurchasesScreen.id),
            ),
            _buildButton(
              'My Selling History',
              () => Navigator.pushNamed(context, SellHistory.id),
            ),
            const SizedBox(height: 20),
            const Text(
              'My Selling Stats',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            const Padding(padding: EdgeInsets.all(10.0), child: Divider()),
            DropdownButton<String>(
              value: dropDownValue,
              items: dropDownItems
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (newValue) {
                if (newValue != null) setState(() => dropDownValue = newValue);
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: kContainerDecoration,
                    child: Text(
                      'Clicks on listings: ${clicksOnListings ?? '—'}',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: kContainerDecoration,
                    child: Text('Total earnings: ${totalEarnings ?? '—'}'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: kContainerDecoration,
                    child: SizedBox(height: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: kContainerDecoration,
                    child: Column(
                      children: [
                        Text('Listings sold: ${listingsSold ?? '—'}'),
                        const SizedBox(height: 10),
                        MaterialButton(
                          color: Colors.grey,
                          onPressed: () =>
                              Navigator.pushNamed(context, SellHistory.id),
                          child: const Text('View Selling'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
            SizedBox(height: 20),
            const Text('Cash', style: TextStyle(fontSize: 30)),
            Text('\$$cash', style: TextStyle(fontSize: 15)),
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: MaterialButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AddMoneyScreen.id);
                    },
                    color: Colors.green,
                    child: Text('Add Money'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: MaterialButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AddMoneyScreen.id);
                    },
                    color: Colors.grey,
                    child: Text('Withdraw Money'),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: MaterialButton(
                onPressed: () {
                  Navigator.pushNamed(context, AddMoneyScreen.id);
                },
                color: Colors.grey,
                child: Text('View transaction history'),
              ),
            ),
            SizedBox(height: 10),
            const Text('Ratings', style: TextStyle(fontSize: 30)),
            const Padding(padding: EdgeInsets.all(10), child: Divider()),
            ReusableStarRating(rating: averageRating ?? 0, starSize: 30),
            Text('Rating: ${averageRating?.toStringAsFixed(1) ?? '—'}'),
            const SizedBox(height: 10),
            MaterialButton(
              color: Colors.grey,
              onPressed: () => Navigator.pushNamed(context, ViewMyRatings.id),
              child: const Text('Ratings'),
            ),
            const SizedBox(height: 20),
            const Text('Watch List', style: TextStyle(fontSize: 20)),
            const Padding(padding: EdgeInsets.all(10.0), child: Divider()),
            // Watch List
            Column(
              children: [
                for (var data in watchListIds)
                  WatchListTemplate(listingId: data),
              ],
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // Reusable button builder to eliminate repetitive Padding/Material/MaterialButton trees.
  Widget _buildButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Material(
        elevation: 5.0,
        color: Colors.grey,
        borderRadius: BorderRadius.circular(30.0),
        child: MaterialButton(
          onPressed: onPressed,
          minWidth: double.infinity,
          height: 42.0,
          child: Text(label),
        ),
      ),
    );
  }
}

class WatchListTemplate extends StatefulWidget {
  final String listingId;
  const WatchListTemplate({super.key, required this.listingId});

  @override
  State<WatchListTemplate> createState() => _WatchListTemplateState();
}

class _WatchListTemplateState extends State<WatchListTemplate> {
  // Holds every field needed for display + navigation.
  // Null means "still loading".
  Map<String, dynamic>? _listing;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetchListing();
  }

  Future<void> _fetchListing() async {
    try {
      final doc = await _firestore
          .collection('listings')
          .doc(widget.listingId)
          .get();

      if (!mounted) return; // widget was disposed before the fetch finished

      if (!doc.exists) {
        setState(() => _error = true);
        return;
      }

      setState(() => _listing = {...doc.data()!, 'id': doc.id});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Loading state ──
    if (_listing == null && !_error) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // ── Error / deleted listing ──
    if (_error) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          'Listing unavailable',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    //
    final listing = _listing!;
    final String listingName = listing['title'] as String? ?? 'Untitled';
    final String sellerEmail = listing['sellerEmail'] as String? ?? '';
    final String description = listing['description'] as String? ?? '';
    final double price = (listing['price'] as num?)?.toDouble() ?? 0.0;
    final int quantity = (listing['quantity'] as num?)?.toInt() ?? 0;
    final List images = listing['images'] as List? ?? [];
    final String sellerId = listing['sellerId'] as String? ?? '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(listingName, style: const TextStyle(fontSize: 18)),
          ),
          MaterialButton(
            color: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddTemplateScreen(
                    listingId: widget.listingId,
                    sellerEmail: sellerEmail,
                    addName: listingName,
                    addDescription: description,
                    addPrice: price,
                    initialQuantity: quantity,
                    images: images,
                    sellerId: sellerId,
                  ),
                ),
              );
            },
            child: const Text('View listing'),
          ),
        ],
      ),
    );
  }
}
