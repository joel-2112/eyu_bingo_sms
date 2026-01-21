class WithdrawTransaction {
  final int id;
  final String amount;
  final String status;
  final String createdAt;
  final TransactionUser user;

  WithdrawTransaction({
    required this.id,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.user,
  });

  factory WithdrawTransaction.fromJson(Map<String, dynamic> json) {
    return WithdrawTransaction(
      id: json['id'],
      amount: json['amount'].toString(),
      status: json['status'] ?? 'pending',
      createdAt: json['createdAt'] ?? '',
      user: TransactionUser.fromJson(json['User'] ?? {}),
    );
  }
}

class TransactionUser {
  final String username;
  final String phoneNumber;

  TransactionUser({required this.username, required this.phoneNumber});

  factory TransactionUser.fromJson(Map<String, dynamic> json) {
    return TransactionUser(
      username: json['username'] ?? 'Unknown',
      phoneNumber: json['phone_number'] ?? 'No Phone',
    );
  }
}