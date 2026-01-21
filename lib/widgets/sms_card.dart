import 'package:flutter/material.dart';
import '../models/synced_sms.dart';

class SmsCard extends StatelessWidget {
  final SyncedSms sms;
  const SmsCard({super.key, required this.sms});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(
          "TXID: ${sms.transactionId}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "${sms.amount} ETB | ${sms.dateReceived}\n${sms.messageContent}",
        ),
        trailing: Icon(
          Icons.check_circle,
          color: sms.isUsed ? Colors.grey : Colors.green,
        ),
      ),
    );
  }
}