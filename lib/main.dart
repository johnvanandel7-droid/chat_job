// screens
import 'package:chat_job/screens/add_money_screen.dart';
import 'package:chat_job/screens/buy_sell_screen.dart';
import 'package:chat_job/screens/chats_screen.dart';
import 'package:chat_job/screens/create_chat_screen.dart';
import 'package:chat_job/screens/create_listing.dart';
import 'package:chat_job/screens/edit_company.dart';
import 'package:chat_job/screens/friends_screen.dart';
import 'package:chat_job/screens/my_listings_screen.dart';
import 'package:chat_job/screens/my_purchases_screen.dart';
import 'package:chat_job/screens/my_company_screen.dart';
import 'package:chat_job/screens/notifications_screen.dart';
import 'package:chat_job/screens/registration_payment_screen.dart';
import 'package:chat_job/screens/sell_history.dart';
import 'package:chat_job/screens/view_my_ratings.dart';
import 'package:chat_job/screens/welcome_screen.dart';
import 'package:chat_job/screens/login_screen.dart';
import 'package:chat_job/screens/registration_screen.dart';
import 'package:chat_job/screens/chat_job_home.dart';

// firestore imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// stripe money managing imports
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;

// other imports
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' as io show Platform;

// local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// background handler (required)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // Initialize binding first
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // === Mobile devices only
  if (!kIsWeb && (io.Platform.isAndroid || io.Platform.isIOS)) {
    // Initialize Stripe with your publishable key
    stripe.Stripe.publishableKey =
        'pk_live_51TUHGCPR5ULPwwRdour035kiiyOPvdFdCjhj7fZJ2vsfFzFo9I0TEST3joIaQP3kE3FPqzUyagdjdYG1ePQKyM1000H6HbmKXg';

    // Set up Stripe for mobile specific configuration
    await stripe.Stripe.instance.applySettings();

    // retreive backround messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // request notification permission
    await requestPermission();

    // init local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(settings: settings);

    // Foreground message listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        flutterLocalNotificationsPlugin.show(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: message.notification!.title,
          body: message.notification!.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              'chat_channel',
              'Chat Messages',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });

    // handle phone token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'phoneToken': newToken});
      }
    });

    // go to correct screen on notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final chatId = message.data['chatId'];

      if (chatId != null && navigatorKey.currentContext != null) {
        Navigator.pushNamed(
          navigatorKey.currentContext!,
          ChatsScreen.id,
          arguments: chatId,
        );
      }
    });
  }

  // all platforms
  // check if the users authentication is still the same
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null) {
      // for mobile update phone token
      if (!kIsWeb && (io.Platform.isIOS || io.Platform.isAndroid)) {
        String? token = await FirebaseMessaging.instance.getToken();

        if (token != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'phoneToken': token}, SetOptions(merge: true));
        }
      }
      // for desktop ensure that user record exists
      else {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'lastLogin': DateTime.now(),
        }, SetOptions(merge: true));
      }
    }
  });

  runApp(ChatJob());
}

Future<void> requestPermission() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  print(settings.authorizationStatus);
}

class ChatJob extends StatelessWidget {
  const ChatJob({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: Colors.blueGrey,
          onPrimary: Colors.black,
          secondary: Colors.grey,
          onSecondary: Colors.green,
          error: Colors.red,
          onError: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        textTheme: TextTheme(bodyLarge: TextStyle(color: Colors.black54)),
        // responsive text scaling
        useMaterial3: true,
      ),
      initialRoute: WelcomeScreen.id,
      routes: {
        WelcomeScreen.id: (context) => WelcomeScreen(),
        LoginScreen.id: (context) => LoginScreen(),
        RegistrationScreen.id: (context) => RegistrationScreen(),
        ChatJobHome.id: (context) => ChatJobHome(),
        BuySellScreen.id: (context) => BuySellScreen(),
        FriendsScreen.id: (context) => FriendsScreen(),
        MyCompany.id: (context) => MyCompany(),
        EditCompany.id: (context) => EditCompany(),
        CreateListing.id: (context) => CreateListing(),
        ChatsScreen.id: (context) => ChatsScreen(),
        CreateChatScreen.id: (context) => CreateChatScreen(),
        MyAddsList.id: (context) => MyAddsList(),
        MyPurchasesScreen.id: (context) => MyPurchasesScreen(),
        SellHistory.id: (context) => SellHistory(),
        NotificationsScreen.id: (context) => NotificationsScreen(),
        ViewMyRatings.id: (context) => ViewMyRatings(),
        RegistrationPaymentScreen.id: (context) => RegistrationPaymentScreen(),
        AddMoneyScreen.id: (context) => AddMoneyScreen(),
      },
    );
  }
}
