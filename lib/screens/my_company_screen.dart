import 'package:chat_job/components/app_bar.dart';
import 'package:chat_job/components/star_rating.dart';
import 'package:chat_job/constants.dart';
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

  String dropDownValue = dropDownItems.first;

  @override
  void initState() {
    super.initState();

    getCurrentUser();
  }

  Future<void> getRating() async {
    if (userUid == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seller profile not found. Please re-register.'),
          ),
        );
      }
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('seller_ratings')
          .where('sellerId', isEqualTo: userUid)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          averageRating = 0;
        });
        return;
      }

      double total = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final rating = (data['rating'] as num?)?.toDouble() ?? 0;
        total += rating;
      }

      double avg = total / snapshot.docs.length;

      setState(() {
        averageRating = avg;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('failed to get ratings')));
    }
  }

  Future<void> getSellerInfo() async {
    if (userUid == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seller profile not found. Please re-register.'),
          ),
        );
      }
      return;
    }

    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(userUid)
          .get();

      if (!docSnapshot.exists) {
        return;
      }

      final data = docSnapshot.data() as Map<String, dynamic>;

      String userName = data['userEmail'] ?? 'unknown';
      int clicks = data['clicksOnListing'] ?? 0;
      double earnings = (data['totalEarnings'] as num?)?.toDouble() ?? 0.0;
      double totalCash = (data['totalCash'] as num?)?.toDouble() ?? 0.0;
      double soldListings = (data['listingsSold'] as num?)?.toDouble() ?? 0.0;

      setState(() {
        userEmail = userName;
        clicksOnListings = clicks;
        totalEarnings = earnings;
        cash = totalCash;
        listingsSold = soldListings;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to show seller info $e')));
    }
  }

  void getCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _companyName = (user.email ?? '').split('@')[0].trim();
        userUid = user.uid;
        userEmail = user.email?.trim().toLowerCase();
      });
    } else {
      setState(() {
        _companyName = 'Not allowed';
      });
    }

    await getRating();
    await getSellerInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(10),
              child: Material(
                elevation: 5.0,
                color: Colors.grey,
                borderRadius: BorderRadius.circular(30.0),
                child: MaterialButton(
                  onPressed: () {
                    Navigator.pushNamed(context, BuySellScreen.id);
                  },
                  minWidth: double.infinity,
                  height: 42.0,
                  child: Text('Buy'),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(10),
              child: Material(
                elevation: 5.0,
                color: Colors.grey,
                borderRadius: BorderRadius.circular(30.0),
                child: MaterialButton(
                  onPressed: () {
                    Navigator.pushNamed(context, EditCompany.id);
                  },
                  minWidth: double.infinity,
                  height: 42.0,
                  child: Text('Edit Company'),
                ),
              ),
            ),
            Text(
              'Company Name',
              style: TextStyle(color: Colors.grey[800], fontSize: 15),
            ),
            Text(
              _companyName ?? 'Not Logged In',
              style: TextStyle(color: Colors.black, fontSize: 30),
            ),
            Padding(
              padding: EdgeInsets.all(10),
              child: Material(
                elevation: 5.0,
                color: Colors.grey,
                borderRadius: BorderRadius.circular(30.0),
                child: MaterialButton(
                  onPressed: () {
                    Navigator.pushNamed(context, CreateListing.id);
                  },
                  minWidth: double.infinity,
                  height: 42.0,
                  child: Text('Create Listing'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Material(
                elevation: 5.0,
                color: Colors.grey,
                borderRadius: BorderRadius.circular(30.0),
                child: MaterialButton(
                  onPressed: () {
                    Navigator.pushNamed(context, MyAddsList.id);
                  },
                  minWidth: double.infinity,
                  child: Text('My Listings'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Material(
                elevation: 5.0,
                color: Colors.grey,
                borderRadius: BorderRadius.circular(30.0),
                child: MaterialButton(
                  onPressed: () {
                    Navigator.pushNamed(context, MyPurchasesScreen.id);
                  },
                  minWidth: double.infinity,
                  child: Text('My Purchases'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Material(
                elevation: 5.0,
                color: Colors.grey,
                borderRadius: BorderRadius.circular(30.0),
                child: MaterialButton(
                  onPressed: () {
                    Navigator.pushNamed(context, SellHistory.id);
                  },
                  minWidth: double.infinity,
                  child: Text('My Selling history'),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'My Selling Stats',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            Padding(padding: const EdgeInsets.all(10.0), child: Divider()),
            DropdownButton(
              value: dropDownValue,
              items: dropDownItems.map<DropdownMenuItem<String>>((
                String value,
              ) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newTimeFrame) {
                setState(() {
                  dropDownValue = newTimeFrame!;
                });
              },
            ),
            SizedBox(height: 20),
            Row(
              children: [
                SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: kContainerDecoration,
                    child: Text('Clicks on listings: $clicksOnListings'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: kContainerDecoration,
                    child: Text('total earnings: $totalEarnings'),
                  ),
                ),
                SizedBox(width: 10),
              ],
            ),
            SizedBox(height: 15),
            Row(
              children: [
                SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: kContainerDecoration,
                    child: Column(
                      children: [
                        Text('Cash: $cash'),
                        SizedBox(height: 10),
                        MaterialButton(
                          onPressed: () {},
                          color: Colors.grey,
                          child: Text('Add money'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: kContainerDecoration,
                    child: Column(
                      children: [
                        Text('Listings sold: $listingsSold'),
                        SizedBox(height: 10),
                        MaterialButton(
                          color: Colors.grey,
                          onPressed: () {
                            Navigator.pushNamed(context, SellHistory.id);
                          },
                          child: Text('View Selling'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 10),
              ],
            ),
            Text('Ratings', style: TextStyle(fontSize: 30)),
            Padding(padding: EdgeInsets.all(10), child: Divider()),
            ReusableStarRating(rating: averageRating ?? 0, starSize: 30),
            Text('Rating: $averageRating'),
            SizedBox(height: 10),
            MaterialButton(
              color: Colors.grey,
              onPressed: () {
                Navigator.pushNamed(context, ViewMyRatings.id);
              },
              child: Text('Ratings'),
            ),
            SizedBox(height: 20),
            Text('Watch List'),
            Padding(padding: const EdgeInsets.all(10.0), child: Divider()),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _firestore.collection('users').doc(userUid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  print('error: ${snapshot.error}');
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text("No Listings yet"));
                }

                final userData = snapshot.data!.data();
                if (userData == null || userData['watchList'].isEmpty) {
                  return const Center(
                    child: Text("No Listings on your watchlist yet"),
                  );
                }

                final watchListData = userData['watchList'];

                for (var doc in watchListData) {}
                return Center();
              },
            ),
            SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}

class DropdownContainer extends StatelessWidget {
  final String containerText;
  const DropdownContainer({super.key, required this.containerText});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        color: Colors.grey[200],
        child: Text(containerText, style: TextStyle(fontSize: 15)),
      ),
    );
  }
}

class WatchListTemplate extends StatelessWidget {
  final String listingName;

  const WatchListTemplate({super.key, required this.listingName});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
