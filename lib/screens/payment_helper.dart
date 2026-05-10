import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
 
class PaymentHelper {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
 
  /// Create a payment intent via Cloud Function
  static Future<Map<String, dynamic>> createPaymentIntent({
    required int amount, // Amount in cents (e.g., 499 for $4.99)
    required String currency,
    required String type, // 'add_money' or 'registration_fee'
  }) async {
    try {
      final result = await _functions
          .httpsCallable('createPaymentIntent')
          .call({
            'amount': amount,
            'currency': currency,
            'type': type,
          });
 
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to create payment intent: $e');
    }
  }
 
  /// Process payment with Stripe
  static Future<bool> processPayment({
    required Map<String, dynamic> paymentIntent,
    required String merchantName,
  }) async {
    try {
      // Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent['client_secret'],
          merchantDisplayName: merchantName,
          style: ThemeMode.light,
        ),
      );
 
      // Present payment sheet to user
      await Stripe.instance.presentPaymentSheet();
 
      return true; // Payment successful
    } on StripeException catch (e) {
      final errorMessage = e.error.message ?? e.toString();
      throw Exception('Payment processing failed: $errorMessage');
    } catch (e) {
      throw Exception('Payment processing failed: $e');
    }
  }
 
  /// Get transaction history for current user
  static Future<List<Map<String, dynamic>>> getTransactionHistory({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
 
      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch transaction history: $e');
    }
  }
 
  /// Get user's wallet balance
  static Future<double> getWalletBalance(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
 
      if (!doc.exists) {
        return 0.0;
      }
 
      final data = doc.data() as Map<String, dynamic>;
      return (data['totalCash'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      throw Exception('Failed to fetch wallet balance: $e');
    }
  }
 
  /// Format amount to currency string
  static String formatCurrency(double amount, {String currency = 'USD'}) {
    return '\$${amount.toStringAsFixed(2)}';
  }
 
  /// Convert dollars to cents for Stripe
  static int dollarsToCents(double dollars) {
    return (dollars * 100).toInt();
  }
 
  /// Convert cents to dollars
  static double centsToDollars(int cents) {
    return cents / 100.0;
  }
 
  /// Verify payment status via Cloud Function
  static Future<Map<String, dynamic>> verifyPayment(
      String paymentIntentId) async {
    try {
      final result = await _functions
          .httpsCallable('verifyPayment')
          .call({'paymentIntentId': paymentIntentId});
 
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to verify payment: $e');
    }
  }
 
  /// Create a transaction record manually (for testing or special cases)
  static Future<void> createTransactionRecord({
    required String userId,
    required String type,
    required double amount,
    required String description,
    String status = 'completed',
  }) async {
    try {
      await _firestore.collection('transactions').add({
        'userId': userId,
        'type': type,
        'amount': amount,
        'status': status,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to create transaction record: $e');
    }
  }
 
  /// Stream wallet balance updates in real-time
  static Stream<double> streamWalletBalance(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return 0.0;
          final data = doc.data() as Map<String, dynamic>;
          return (data['totalCash'] as num?)?.toDouble() ?? 0.0;
        });
  }
 
  /// Stream transaction updates
  static Stream<List<Map<String, dynamic>>> streamTransactions(String userId) {
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data(),
                  })
              .toList();
        });
  }
}