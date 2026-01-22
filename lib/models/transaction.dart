class WithdrawTransaction {
  final int id;
  final double amount;
  final String status;
  final String description;
  final String balanceType; // Added this to match your backend logic
  final TransactionUser user;

  WithdrawTransaction({
    required this.id,
    required this.amount,
    required this.status,
    required this.description,
    required this.balanceType,
    required this.user,
  });

  factory WithdrawTransaction.fromJson(Map<String, dynamic> json) {
    return WithdrawTransaction(
      // Safely parse ID in case it comes as a string from the API
      id: int.tryParse(json['id'].toString()) ?? 0,
      
      // Safe parsing for amount
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      
      status: json['status']?.toString() ?? "pending",
      description: json['description'] ?? "",
      
      // Important for your backend logic: "real" or "bonus"
      balanceType: json['balance_type'] ?? "real", 
      
      // Matches the 'as: "User"' alias from your controller
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
      username: json['username'] ?? "User",
      
      // Standardizes the phone number field
      phoneNumber: (json['phone_number'] ?? json['phoneNumber'] ?? "N/A").toString(),
    );
  }
}