import 'package:chat_job/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';

final _firestore = FirebaseFirestore.instance;
final _auth = FirebaseAuth.instance;

class AddMoneyScreen extends StatefulWidget {
  static const id = 'add_money_screen';
  const AddMoneyScreen({super.key});

  @override
  State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  String? addedMoney;
  String? noteText;
  bool isProcessing = false;
  String? errorMessage;

  // Quick select amounts in dollars
  final List<int> quickAmounts = [10, 25, 50, 100];

  @override
  Widget build(BuildContext context) {
    final currentUserUid = _auth.currentUser?.uid;

    if (currentUserUid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Money')),
        body: const Center(child: Text('You must be logged in to add money')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Money to Wallet'),
        backgroundColor: Colors.blueAccent,
      ),
      body: ModalProgressHUD(
        inAsyncCall: isProcessing,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.wallet, size: 40, color: Colors.blue),
                      const SizedBox(height: 10),
                      const Text(
                        'Add funds to your wallet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use these funds to purchase items or pay for services',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Custom amount section
                const Text(
                  'Enter Amount',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: const Text(
                          '\$',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              addedMoney = value.isEmpty ? null : value;
                              errorMessage = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Quick select buttons
                const Text(
                  'Quick Select',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: quickAmounts.map((amount) {
                    final isSelected = addedMoney == amount.toString();
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          addedMoney = amount.toString();
                          errorMessage = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? Colors.blue : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          '\$${amount.toString()}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 30),

                // Optional note section
                const Text(
                  'Note (optional)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextField(
                  maxLines: 3,
                  maxLength: 200,
                  decoration: kInputDecoration.copyWith(
                    hintText: 'Add a note for your records',
                  ),
                  onChanged: (value) {
                    setState(() => noteText = value);
                  },
                ),
                const SizedBox(height: 10),

                // Error message
                if (errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border.all(color: Colors.red[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      errorMessage!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                const SizedBox(height: 30),

                // Add money button
                ElevatedButton(
                  onPressed: (addedMoney == null || addedMoney!.isEmpty)
                      ? null
                      : () => _processPayment(currentUserUid),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    disabledBackgroundColor: Colors.grey[400],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Add Money Securely',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // Info box
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Payments are processed securely by Stripe. Your card info is never stored on our servers.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _processPayment(String userId) async {
    // Validate input
    final amount = double.tryParse(addedMoney ?? '');
    if (amount == null || amount <= 0) {
      setState(() {
        errorMessage = 'Please enter a valid amount greater than \$0';
      });
      return;
    }

    if (amount > 10000) {
      setState(() {
        errorMessage = 'Maximum amount is \$10,000';
      });
      return;
    }

    setState(() {
      isProcessing = true;
      errorMessage = null;
    });

    try {
      // Step 1: Create payment intent on your backend
      // You'll need a Firebase Cloud Function or backend server for this
      final paymentIntent = await _createPaymentIntent(
        amount: (amount * 100).toInt(), // Convert to cents
        currency: 'usd',
      );

      // Step 2: Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent['client_secret'],
          merchantDisplayName: 'Chat Job',
          style: ThemeMode.light,
          // You can add custom styling here
        ),
      );

      // Step 3: Present payment sheet to user
      await Stripe.instance.presentPaymentSheet();

      // Step 4: Payment successful - update Firestore
      await _firestore.collection('users').doc(userId).set({
        'totalCash': FieldValue.increment(amount),
      }, SetOptions(merge: true));

      // Step 5: Log transaction in ledger
      await _firestore.collection('transactions').add({
        'userId': userId,
        'type': 'deposit',
        'amount': amount,
        'status': 'completed',
        'description':
            'Wallet top-up${noteText != null && noteText!.isNotEmpty ? ': $noteText' : ''}',
        'paymentMethod': 'card',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => isProcessing = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully added \$${amount.toStringAsFixed(2)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Clear form
        setState(() {
          addedMoney = null;
          noteText = null;
        });

        // Optionally navigate back after delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } on StripeException catch (e) {
      if (mounted) {
        setState(() {
          isProcessing = false;
          errorMessage = 'Payment failed: ${e.error.localizedMessage}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isProcessing = false;
          errorMessage = 'Payment error: $e';
        });
      }
    }
  }

  // This should be called from your backend (Firebase Cloud Function)
  // For now, this is a placeholder - implement with your actual backend
  Future<Map<String, dynamic>> _createPaymentIntent({
    required int amount,
    required String currency,
  }) async {
    try {
      // IMPORTANT: Call your backend API to create payment intent
      // Example using Firebase Cloud Function:
      // final response = await FirebaseFunctions.instance
      //     .httpsCallable('createPaymentIntent')
      //     .call({'amount': amount, 'currency': currency});
      // return response.data;

      // TEMPORARY: This is a mock - replace with actual backend call
      throw Exception(
        'Backend integration required. '
        'Implement createPaymentIntent Cloud Function.',
      );
    } catch (e) {
      rethrow;
    }
  }
}
