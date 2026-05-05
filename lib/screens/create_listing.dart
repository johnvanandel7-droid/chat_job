import 'dart:io';
import 'package:chat_job/components/app_bar.dart';
import 'package:chat_job/constants.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class CreateListing extends StatefulWidget {
  static const id = 'create_listing';
  const CreateListing({super.key});

  @override
  State<CreateListing> createState() => _CreateListingState();
}

class _CreateListingState extends State<CreateListing> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final ImagePicker _picker = ImagePicker();

  String description = '';
  String title = '';
  double? price;
  double? quantity;
  String? currentUserEmail;
  String? currentUserUid;

  List<XFile> images = [];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    getCurrentUser();
  }

  Future<void> pickImage() async {
    // Show a nice dialog to let user choose Camera or Gallery
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Image'),
        content: const Text('Choose where to get the image from:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('📷 Take Photo'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('🖼️ Choose from Gallery'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context), // Cancel
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    // If user cancelled the dialog
    if (source == null) return;

    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);

      if (picked != null) {
        setState(() {
          images.add(picked);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Future<List<String>> uploadImages() async {
    List<String> imageUrls = [];

    for (var xFile in images) {
      final originalFile = File(xFile.path);

      // Get temporary directory for compressed file
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';

      // Compress the image (good balance for listings)
      final XFile? compressedXFile =
          await FlutterImageCompress.compressAndGetFile(
            originalFile.absolute.path,
            targetPath,
            quality:
                85, // 80-90 is recommended (good quality + big size reduction)
            minWidth: 1200, // Max width (keeps aspect ratio)
            minHeight: 1200, // Max height
            format: CompressFormat.jpeg,
          );

      final fileToUpload = compressedXFile != null
          ? File(compressedXFile.path)
          : originalFile;

      // read bytes for upload
      final bytes = await fileToUpload.readAsBytes();

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${xFile.name}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('listing_images')
          .child(fileName);

      final task = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final url = await task.ref.getDownloadURL();
      imageUrls.add(url);

      // Clean up Temporary files
      if (compressedXFile != null) {
        try {
          await File(compressedXFile.path).delete();
        } catch (_) {}
      }
    }

    return imageUrls;
  }

  Future<void> createListing() async {
    if (title.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enter a title',
            style: TextStyle(color: Colors.red, fontSize: 20),
          ),
        ),
      );
      return;
    }

    if (price == null || price! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enter a valid price',
            style: TextStyle(color: Colors.red, fontSize: 20),
          ),
        ),
      );
      return;
    }

    if (currentUserEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final imageUrls = await uploadImages();

      await _firestore.collection('listings').add({
        'title': title.trim(),
        'description': description.trim(),
        'price': price,
        'images': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'quantity': quantity ?? 1,
        'sellerEmail': currentUserEmail,
        'clicks': 0,
        'sellerId': currentUserUid,
        'listingsSold': 0,
      });

      if (!mounted) return;
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing created successfully!')),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e ")));
    }
    setState(() {
      isLoading = false;
    });
  }

  void getCurrentUser() {
    final user = _auth.currentUser;
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

  Widget buildImagePreview(XFile image) {
    return Padding(
      padding: EdgeInsets.all(10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.file(
              File(image.path),
              width: 150,
              height: 150,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  images.remove(image);
                });
              },
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.red,
                child: Icon(Icons.close, color: Colors.white, size: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 20),
            Text('Listing Name'),
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: TextField(
                decoration: kInputDecoration2,
                onChanged: (value) {
                  title = value;
                },
              ),
            ),
            SizedBox(
              height: 180,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...images.map(buildImagePreview),
                  // Always last Add image button
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Material(
                      elevation: 5.0,
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20.0),
                      child: MaterialButton(
                        onPressed: pickImage,
                        minWidth: 50,
                        height: 150.0,
                        child: Text('Add Image'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(padding: EdgeInsets.all(10), child: Text('Description')),
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: TextField(
                maxLines: 8,
                maxLength: 500,
                decoration: kInputDecoration2,
                onChanged: (value) {
                  description = value;
                },
              ),
            ),
            Padding(padding: EdgeInsets.all(5), child: Text('Price')),
            Padding(
              padding: EdgeInsets.all(15),
              child: TextField(
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: kInputDecoration2,
                onChanged: (value) {
                  price = double.tryParse(value);
                },
              ),
            ),
            Padding(padding: EdgeInsets.all(5), child: Text('Quantity')),
            Padding(
              padding: EdgeInsets.all(15),
              child: TextField(
                decoration: kInputDecoration2,
                onChanged: (value) {
                  quantity = double.tryParse(value) ?? 1;
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 60),
              child: Material(
                elevation: 5.0,
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(15.0),
                child: MaterialButton(
                  onPressed: () async {
                    await createListing();
                  },
                  minWidth: double.infinity,
                  height: 40.0,
                  child: isLoading
                      ? CircularProgressIndicator(color: Colors.black)
                      : Text('Save Listing'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
