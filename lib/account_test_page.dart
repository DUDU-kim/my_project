import 'package:flutter/material.dart';

class AccountTestPage extends StatefulWidget {
  const AccountTestPage({super.key});

  @override
  State<AccountTestPage> createState() => _AccountTestPage();
}

class _AccountTestPage extends State<AccountTestPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        elevation: 0,
      ),

      body: const Center(
        child: Text(
          '測試用頁面',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}