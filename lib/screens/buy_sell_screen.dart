import 'package:chat_job/screens/my_company_screen.dart';
import 'package:flutter/material.dart';
import 'package:chat_job/components/app_bar.dart';
import 'package:chat_job/constants.dart';
import 'package:chat_job/components/add_template.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final _firestore = FirebaseFirestore.instance;

class BuySellScreen extends StatefulWidget {
  static const id = 'BuySell';

  const BuySellScreen({super.key});

  @override
  State<BuySellScreen> createState() => _BuySellScreenState();
}

class _BuySellScreenState extends State<BuySellScreen> {
  String _keyword = '';
  String? _selectedCategory;
  double _minPrice = 0;
  double _maxPrice = 1000;
  String _sortBy = 'newest';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(10),
            child: Material(
              elevation: 5.0,
              color: Colors.grey,
              borderRadius: BorderRadius.circular(30.0),
              child: MaterialButton(
                onPressed: () {
                  Navigator.pushNamed(context, MyCompany.id);
                },
                minWidth: double.infinity,
                height: 42.0,
                child: Text('My Company'),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: TextField(
              decoration: kInputDecoration2.copyWith(
                hintText: 'Search listings...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: () async {
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => FilterSheet(
                        selectedCategory: _selectedCategory,
                        minPrice: _minPrice,
                        maxPrice: _maxPrice,
                        sortBy: _sortBy,
                        onApply: (category, min, max, sort) {
                          setState(() {
                            _selectedCategory = category;
                            _minPrice = min;
                            _maxPrice = max;
                            _sortBy = sort;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              onChanged: (newText) {
                setState(() {
                  _keyword = newText.trim().toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: AddsList(
              keyword: _keyword,
              category: _selectedCategory,
              minPrice: _minPrice,
              maxPrice: _maxPrice,
              sortBy: _sortBy,
            ),
          ),
        ],
      ),
    );
  }
}

class AddsList extends StatelessWidget {
  final String keyword;
  final String? category;
  final double minPrice;
  final double maxPrice;
  final String sortBy;

  const AddsList({
    super.key,
    this.keyword = '',
    this.category,
    this.minPrice = 0,
    this.maxPrice = 1000,
    this.sortBy = 'newest',
  });

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = _firestore.collection('listings');

    if (category != null) {
      q = q.where('category', isEqualTo: category);
    }

    // Only apply price filter if user actually moved the slider
    if (minPrice > 0) {
      q = q.where('price', isGreaterThanOrEqualTo: minPrice);
    }
    if (maxPrice < 1000) {
      q = q.where('price', isLessThanOrEqualTo: maxPrice);
    }

    switch (sortBy) {
      case 'price_asc':
        q = q.orderBy('price');
      case 'price_desc':
        q = q.orderBy('price', descending: true);
      default:
        q = q.orderBy('createdAt', descending: true);
    }

    return q;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('error: ${snapshot.error}');
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No Listings yet"));
        }

        final docs = snapshot.data!.docs;
        final List<AddTemplate> adds = [];

        for (var doc in docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;

            final title = (data['title'] as String?)?.trim() ?? 'Untitled';
            final description = (data['description'] as String?)?.trim() ?? '';
            final price = (data['price'] as num?)?.toDouble() ?? 0.0;
            final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
            final userEmail = (data['sellerEmail'] as String?)?.trim() ?? '';
            final userId = (data['sellerId'] as String);

            if (userEmail.isEmpty || userId.isEmpty) continue;

            // Keyword filter
            if (keyword.isNotEmpty) {
              final hayStack =
                  '${title.toLowerCase()} ${description.toLowerCase()}';
              if (!hayStack.contains(keyword)) continue;
            }

            // Safe images handling
            final imagesRaw = data['images'];
            final List<String> images = imagesRaw is List
                ? imagesRaw.whereType<String>().toList()
                : <String>[];

            adds.add(
              AddTemplate(
                sellerEmail: userEmail,
                addName: title,
                addDescription: description,
                addPrice: price,
                quantity: quantity,
                images: images,
                listingId: doc.id,
                sellerId: userId,
              ),
            );
          } catch (e) {
            print('Error parsing listing ${doc.id}: $e');
          }
        }

        if (adds.isEmpty) {
          return const Center(child: Text("No valid listings found"));
        }

        return ListView(
          reverse: false,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          children: adds,
        );
      },
    );
  }
}

class FilterSheet extends StatefulWidget {
  final String? selectedCategory;
  final double minPrice;
  final double maxPrice;
  final String sortBy;
  final void Function(String?, double, double, String) onApply;

  const FilterSheet({
    super.key,
    required this.selectedCategory,
    required this.minPrice,
    required this.maxPrice,
    required this.sortBy,
    required this.onApply,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  String? _category;
  late RangeValues _priceRange;
  late String _sortBy;

  final List<String> categories = [
    'Electronics',
    'Furniture',
    'Clothing',
    'Tools',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _category = widget.selectedCategory;
    _priceRange = RangeValues(widget.minPrice, widget.maxPrice);
    _sortBy = widget.sortBy;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              // "All" chip to clear category
              ChoiceChip(
                label: const Text('All'),
                selected: _category == null,
                onSelected: (_) => setState(() => _category = null),
              ),
              ...categories.map(
                (c) => ChoiceChip(
                  label: Text(c),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Price: \$${_priceRange.start.toInt()} – \$${_priceRange.end.toInt()}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 1000,
            divisions: 100,
            onChanged: (v) => setState(() => _priceRange = v),
          ),
          const SizedBox(height: 16),
          const Text('Sort by', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _sortBy,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'newest', child: Text('Newest first')),
              DropdownMenuItem(
                value: 'price_asc',
                child: Text('Price: low to high'),
              ),
              DropdownMenuItem(
                value: 'price_desc',
                child: Text('Price: high to low'),
              ),
            ],
            onChanged: (v) => setState(() => _sortBy = v!),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(
                  _category,
                  _priceRange.start,
                  _priceRange.end,
                  _sortBy,
                );
                Navigator.pop(context);
              },
              child: const Text('Apply filters'),
            ),
          ),
          SizedBox(height: 50),
        ],
      ),
    );
  }
}
