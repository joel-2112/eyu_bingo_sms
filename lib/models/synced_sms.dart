class SyncedSms {
  final int id;
  final String dateReceived;
  final String sender;
  final String messageContent;
  final String transactionId;
  final String amount;
  final bool isUsed;

  SyncedSms({
    required this.id,
    required this.dateReceived,
    required this.sender,
    required this.messageContent,
    required this.transactionId,
    required this.amount,
    required this.isUsed,
  });

  factory SyncedSms.fromJson(Map<String, dynamic> json) {
    return SyncedSms(
      id: json['id'] as int,
      dateReceived: json['date_received'] as String? ?? '',
      sender: json['sender'] as String? ?? '',
      messageContent: json['message_content'] as String? ?? '',
      transactionId: json['transaction_id'] as String? ?? '',
      amount: json['amount'] as String? ?? '',
      isUsed: json['is_used'] as bool? ?? false,
    );
  }
}