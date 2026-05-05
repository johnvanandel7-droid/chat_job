import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_job/components/app_bar.dart';
import 'package:chat_job/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditListing extends StatefulWidget {
  final String listingId;
  final String title;
  final String description;
  final double price;
  final List<dynamic> images;
  final dynamic quantity;

  const EditListing({
    super.key,
    required this.listingId,
    required this.title,
    required this.description,
    required this.price,
    required this.images,
    required this.quantity,
  });

  @override
  State<EditListing> createState() => _EditListingState();
}

class _EditListingState extends State<EditListing> {
  late TextEditingController titleController;
  late TextEditingController descriptionController;
  late TextEditingController priceController;
  late TextEditingController quantityController;

  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  List<String> currentImages = [];
  List<File> newImages = [];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.title);
    descriptionController = TextEditingController(text: widget.description);
    priceController = TextEditingController(text: widget.price.toString());
    quantityController = TextEditingController(
      text: widget.quantity.toString(),
    );

    // initialize the current images
    currentImages = widget.images.map((e) => e.toString()).toList();
  }

  Future<void> addImage() async {
    final ImageSource? source = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Image'),
        content: Text('Choose Source'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, ImageSource.gallery);
            },
            child: Text('Gallery'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, ImageSource.camera);
            },
            child: Text('Camera'),
          ),
        ],
      ),
    );

    if (source == null) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (pickedFile != null) {
        setState(() {
          newImages.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image $e')));
    }
  }

  // upload new image
  Future<List<String>> _uploadNewImages() async {
    List<String> uploadedUrls = [];

    for (var file in newImages) {
      final fileName =
          'listings/${widget.listingId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref(fileName);

      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      uploadedUrls.add(downloadUrl);
    }

    return uploadedUrls;
  }

  Future<void> updateListing() async {
    final newPrice = double.tryParse(priceController.text.trim());
    final newQuantity =
        int.tryParse(quantityController.text.trim()) ?? widget.quantity;

    if (titleController.text.trim().isEmpty ||
        newPrice == null ||
        newPrice <= 0 ||
        newQuantity == widget.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please change something before saving")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      List<String> allImageUrls = List.from(currentImages);

      // upload new images if there are any
      if (newImages.isNotEmpty) {
        final newUrls = await _uploadNewImages();
        allImageUrls.addAll(newUrls);
      }

      // update firestore
      await _firestore.collection('listings').doc(widget.listingId).update({
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'price': newPrice,
        'quantity': newQuantity,
        'images': allImageUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Listing updated successfully!")),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Update failed: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> deleteImage(String imageUrl) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Image?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);

    try {
      // delete using storage url
      final storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
      await storageRef.delete();

      // Remove from Firestore array
      await _firestore.collection('listings').doc(widget.listingId).update({
        'images': FieldValue.arrayRemove([imageUrl]),
      });

      setState(() {
        currentImages.remove(imageUrl);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image deleted successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to delete image: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Text('Listing Name'),
            ),
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: TextField(
                controller: titleController,
                decoration: kInputDecoration2,
              ),
            ),

            // Images Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Text('Images'),
            ),
            SizedBox(
              height: 240,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(10),
                itemCount: currentImages.length + newImages.length + 1,
                itemBuilder: (context, index) {
                  if (index == currentImages.length + newImages.length) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTap: addImage,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 50),
                              SizedBox(height: 8),
                              Text('Add Image'),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final isNew = index >= currentImages.length;
                  final source = isNew
                      ? newImages[index - currentImages.length].path
                      : currentImages[index];

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: isNew
                                  ? Image.file(
                                      File(source),
                                      width: 160,
                                      height: 160,
                                      fit: BoxFit.cover,
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: source,
                                      width: 160,
                                      height: 160,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                      errorWidget: (_, __, ___) =>
                                          const Icon(Icons.error, size: 50),
                                    ),
                            ),
                            Positioned(
                              right: 4,
                              top: 4,
                              child: GestureDetector(
                                onTap: () => isNew
                                    ? setState(
                                        () => newImages.removeAt(
                                          index - currentImages.length,
                                        ),
                                      )
                                    : deleteImage(source),
                                child: const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.red,
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isNew ? "New" : "Current",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text('Description'),
            ),
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: TextField(
                controller: descriptionController,
                maxLines: 8,
                maxLength: 500,
                decoration: kInputDecoration2,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                children: [
                  Text('Price'),
                  SizedBox(width: 20),
                  Expanded(
                    child: TextField(
                      controller: priceController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: kInputDecoration2,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(10),
              child: Row(
                children: [
                  Text('Quantity'),
                  SizedBox(width: 20),
                  Expanded(
                    child: TextField(
                      controller: quantityController,
                      decoration: kInputDecoration2,
                      keyboardType: TextInputType.numberWithOptions(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 20, 15, 60),
              child: Material(
                elevation: 5.0,
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(15.0),
                child: MaterialButton(
                  onPressed: isLoading ? null : updateListing,
                  minWidth: double.infinity,
                  height: 50,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    quantityController.dispose();
    super.dispose();
  }
}
