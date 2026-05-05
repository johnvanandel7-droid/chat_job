import 'package:chat_job/components/app_bar.dart';
import 'package:chat_job/constants.dart';
import 'package:flutter/material.dart';

class EditCompany extends StatefulWidget {
  static const id = 'edit_company';
  const EditCompany({super.key});

  @override
  State<EditCompany> createState() => _EditCompanyState();
}

class _EditCompanyState extends State<EditCompany> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Text('Edit Company', style: TextStyle(fontSize: 25)),
            Padding(
              padding: EdgeInsets.all(20),
              child: TextField(
                decoration: kInputDecoration3,
                onChanged: (value) {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
