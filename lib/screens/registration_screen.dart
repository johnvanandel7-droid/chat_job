import 'package:chat_job/components/round_button.dart';
import 'package:chat_job/constants.dart';
import 'package:chat_job/screens/chat_job_home.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chat_job/components/go_home_button.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';

final _firestore = FirebaseFirestore.instance;
final _messaging = FirebaseMessaging.instance;

class RegistrationScreen extends StatefulWidget {
  static const id = 'registration_screen';

  const RegistrationScreen({super.key});
  @override
  // ignore: library_private_types_in_public_api
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool showSpinner = false;
  String? email;
  String? password;
  bool allowedEntry = false;
  String deniedEntryReason = '';

  Future<void> _registerUser() async {
    // Clear previous error
    setState(() {
      deniedEntryReason = '';
      showSpinner = true;
    });

    // Basic validation
    if (email == null ||
        email!.trim().isEmpty ||
        password == null ||
        password!.trim().isEmpty) {
      setState(() {
        deniedEntryReason = 'Please fill in both email and password';
        showSpinner = false;
      });
      return;
    }

    try {
      // Create user in Firebase Authentication
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: email!.trim(),
            password: password!.trim(),
          );

      // create seller information doc
      final String uid = userCredential.user!.uid;

      final docRef = _firestore.collection('users').doc(uid);

      // variable to remember what phone is what user
      String? token = await _messaging.getToken();

      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set({
          'userId': uid,
          'userEmail': email!.trim(),
          'clicksOnListing': 0,
          'totalEarnings': 0,
          'totalCash': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'listingsSold': 0,
          'phoneToken': token,
        });
      }

      if (!mounted) return;

      // 3. Navigate to home on success
      Navigator.pushNamedAndRemoveUntil(
        context,
        ChatJobHome.id,
        (route) => false, // Clear navigation stack
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'weak-password':
          message = 'Password is too weak. Use at least 6 characters.';
          break;
        case 'email-already-in-use':
          message = 'This email is already registered. Try logging in instead.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;
        default:
          message = e.message ?? 'Registration failed. Please try again.';
      }

      setState(() => deniedEntryReason = message);
    } catch (e) {
      setState(() => deniedEntryReason = 'Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() => showSpinner = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        actions: [GoHomeButton()],
        title: Text('Create Account', style: kAppBarTextStyle),
      ),
      body: ModalProgressHUD(
        inAsyncCall: showSpinner,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Flexible(
                child: Hero(
                  tag: 'logo',
                  child: SizedBox(
                    height: 200.0,
                    child: Image.asset('images/chat_icon.png'),
                  ),
                ),
              ),
              SizedBox(height: 48.0),
              TextField(
                keyboardType: TextInputType.emailAddress,
                textAlign: TextAlign.center,
                onChanged: (value) {
                  setState(() {
                    email = value;
                  });
                },
                decoration: kInputDecoration.copyWith(
                  hintText: 'Enter your Email',
                ),
              ),
              SizedBox(height: 8.0),
              TextField(
                obscureText: true,
                textAlign: TextAlign.center,
                onChanged: (value) {
                  setState(() {
                    password = value;
                  });
                },
                decoration: kInputDecoration.copyWith(
                  hintText: 'Create a Password',
                ),
              ),
              SizedBox(height: 10),
              Text(deniedEntryReason, style: kErrorMessageStyle),
              SizedBox(height: 24.0),
              RoundButton(
                onPressed: _registerUser,
                text: 'Create Account',
                color: Colors.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
