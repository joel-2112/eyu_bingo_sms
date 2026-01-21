import 'package:flutter/material.dart';

class WithdrawRequestScreen extends StatelessWidget {
  const WithdrawRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Withdraw Requests")),
      body: const Center(
        child: Text("Withdraw Test - Coming Soon", style: TextStyle(fontSize: 18)),
      ),
    );
  }
}