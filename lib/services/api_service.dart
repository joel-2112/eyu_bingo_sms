import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/synced_sms.dart';
import '../models/transaction.dart';

class ApiService {
  static const String backendUrl = 'https://eyu-bingo.onrender.com/sms/receive';
  static const String syncSmsUrl =
      'https://eyu-bingo.onrender.com/sms/sync-sms';
  static const String secretKey = 'sms127eyuebingo2025';

  final Dio _dio = Dio();

  Future<bool> sendSmsToBackend(String sender, String message) async {
    try {
      final response = await _dio.post(
        backendUrl,
        data: {'sender': sender, 'message': message, 'secret_key': secretKey},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<SyncedSms>> fetchSyncedSms() async {
    try {
      final response = await _dio.get(
        syncSmsUrl,
        queryParameters: {'secret_key': secretKey},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List data = response.data['data'];
        return data.map((json) => SyncedSms.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

// Fetch Transactions
Future<List<WithdrawTransaction>> fetchWithdrawals() async {
  try {
    final response = await _dio.get(
      'https://eyu-bingo.onrender.com/transactions',
    );
    
    if (response.statusCode == 200) {
      // Your controller sends: { success: true, data: result.rows, ... }
      // So we access data first.
      final List rows = response.data['data']; 
      
      return rows.map((json) => WithdrawTransaction.fromJson(json)).toList();
    }
    return [];
  } catch (e) {
    // debugPrint("Fetch Error: $e");
    rethrow;
  }
}

  // Update Status
Future<bool> updateWithdrawStatus(int id, String status, {String? note}) async {
  try {
    final response = await _dio.put(
      'https://eyu-bingo.onrender.com/transactions/complete-withdraw/$id',
      data: {
        'status': status,          // Matches req.body.status
        'description': note ?? "", // Matches req.body.description
      },
    );

    // If your backend returns res.status(200).json({ success: true })
    return response.data['success'] == true;
  } on DioException catch (e) {
    debugPrint("Update Failed: ${e.response?.data ?? e.message}");
    return false;
  } catch (e) {
    debugPrint("Error: $e");
    return false;
  }
}

}
