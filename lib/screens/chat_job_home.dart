import 'package:flutter/material.dart';
import 'package:chat_job/components/app_bar.dart';

class ChatJobHome extends StatefulWidget {
  static const id = 'chat_job_home';

  const ChatJobHome({super.key});

  @override
  State<ChatJobHome> createState() => _ChatJobHomeState();
}

class _ChatJobHomeState extends State<ChatJobHome> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(
              'Chat Job',
              style: TextStyle(
                color: Colors.black,
                fontSize: 60,
              )
            ),
          ),
          FilledButton(
            onPressed: () {
              
            },
            child: Text('Create post'),                
          ),
        ],
      )
    );
  }
}