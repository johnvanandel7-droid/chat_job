import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:chat_job/screens/add_money_screen.dart';
import 'package:chat_job/screens/registration_screen.dart';
import 'package:flutter/material.dart';

class RegistrationPaymentScreen extends StatelessWidget {
  static const id = 'registrationPaymentScreen';
  const RegistrationPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          Row(
            children: <Widget>[
              SizedBox(width: 20),
              Hero(
                tag: 'logo',
                child: SizedBox(
                  height: 60,
                  child: Image.asset('images/chat_icon.png'),
                ),
              ),
              SizedBox(width: 20),
              DefaultTextStyle(
                style: TextStyle(
                  fontSize: 45.0,
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
                child: AnimatedTextKit(
                  animatedTexts: [TypewriterAnimatedText('Chat Job')],
                ),
              ),
            ],
          ),
          SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Text(
              'You will have to pay for this app so we have less lowballers and people with un serios listings. It is also so we have less kids on the app',
            ),
          ),
          MaterialButton(
            onPressed: () {
              Navigator.pushNamed(context, AddMoneyScreen.id);
            },
            minWidth: 200,
            height: 50,
            color: Colors.blue,
            child: Text('Pay now'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, RegistrationScreen.id);
            },
            child: Text('Start a free trial'),
          ),
        ],
      ),
    );
  }
}
