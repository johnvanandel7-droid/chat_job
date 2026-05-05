import 'package:chat_job/constants.dart';
import 'package:flutter/material.dart';

class AddMoneyScreen extends StatefulWidget {
  static const id = 'add_money_screen';
  const AddMoneyScreen({super.key});

  @override
  State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  String? addedMoney;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            Text('Add Money', style: TextStyle(fontSize: 30)),
            SizedBox(height: 20),
            Text('Amount'),
            TextField(
              decoration: kInputDecoration,
              onChanged: (newValue) {
                addedMoney = newValue;
              },
            ),
            SizedBox(height: 10),
            Text('Quick Select'),
            Row(
              children: [
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: Text('\$10'),
                  ),
                ),
              ],
            ),
            Text('Note(optional)'),
            TextField(decoration: kInputDecoration, onChanged: (newText) {}),
            MaterialButton(
              color: Colors.green,
              onPressed: () {},
              child: Text('Add money'),
            ),
          ],
        ),
      ),
    );
  }
}
