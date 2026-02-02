import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/synced_sms.dart';
import '../models/transaction.dart';

class ApiService {
  static const String baseUrl = 'https://eyu-bingo.onrender.com';
  static const String secretKey = 'sms127eyuebingo2025';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  // 1. SMS ወደ Backend መላክ
  Future<bool> sendSmsToBackend(String sender, String message) async {
    try {
      final response = await _dio.post(
        '/sms/receive',
        data: {'sender': sender, 'message': message, 'secret_key': secretKey},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("SMS Sync Error: $e");
      return false;
    }
  }

  // 2. የተመሳሰሉ SMS መረጃዎችን ማምጣት
  Future<List<SyncedSms>> fetchSyncedSms() async {
    try {
      final response = await _dio.get(
        '/sms/sync-sms',
        queryParameters: {'secret_key': secretKey},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List data = response.data['data'];
        return data.map((json) => SyncedSms.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Fetch SMS Error: $e");
      rethrow;
    }
  }

  // 3. የገንዘብ ወጪ መጠየቂያዎችን (Withdrawals) ማምጣት
  Future<List<WithdrawTransaction>> fetchWithdrawals() async {
    try {
      final response = await _dio.get('/transactions');
      if (response.statusCode == 200) {
        final List rows = response.data['data'];
        return rows.map((json) => WithdrawTransaction.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Fetch Withdrawals Error: $e");
      rethrow;
    }
  }

  // 4. የትራንዛክሽን ሁኔታን ማሻሻል (Update Status)
  Future<bool> updateWithdrawStatus(
    int id,
    String status, {
    String? note,
  }) async {
    try {
      final response = await _dio.put(
        '/transactions/complete-withdraw/$id',
        data: {'status': status, 'description': note ?? ""},
      );
      return response.data['success'] == true;
    } on DioException catch (e) {
      debugPrint("Update Failed: ${e.response?.data ?? e.message}");
      return false;
    } catch (e) {
      return false;
    }
  }

  // 5. ሁሉንም ተጠቃሚዎች ማምጣት
  Future<List<dynamic>> getAllUsers() async {
    try {
      final response = await _dio.get('/users');
      if (response.statusCode == 200) {
        final data = response.data['data'];
        return data as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint("Get Users Error: $e");
      rethrow;
    }
  }

  // 6. ሩም መመዝገብ (Create Room)
  Future<bool> createRoom({
    required String name,
    required double entryFee,
    required int maxPlayers,
    required double commissionRate,
    double? agentCommissionRate,
    String? agentTelegramId,
  }) async {
    try {
      final response = await _dio.post(
        '/rooms',
        data: {
          'name': name.trim(),
          'entry_fee': entryFee,
          'max_players': maxPlayers,
          'commission_rate': commissionRate,
          // እዚህ ጋር ባዶ ስቲሪንግ (Empty String) እንዳይላክ ጥንቃቄ እናደርጋለን
          if (agentCommissionRate != null)
            'agent_commission_rate': agentCommissionRate,
          if (agentTelegramId != null && agentTelegramId.isNotEmpty)
            'agent_telegram_id': agentTelegramId,
        },
      );
      // ባክኤንድህ 201 ነው የሚመልሰው
      return response.statusCode == 201 || (response.data['success'] == true);
    } on DioException catch (e) {
      // ለዴባጊንግ እንዲመች የባክኤንዱን ትክክለኛ Error Message እዚህ እናያለን
      debugPrint("Create Room Server Error: ${e.response?.data}");
      return false;
    } catch (e) {
      debugPrint("Create Room Unexpected Error: $e");
      return false;
    }
  }

  // 7. ሁሉን ሩሞች ማምጣት (Get All Rooms)
  Future<List<dynamic>> getAllRooms() async {
    try {
      final response = await _dio.get('/rooms');
      if (response.statusCode == 200) {
        return response.data['data'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint("Fetch Rooms Error: $e");
      rethrow;
    }
  }

  // 8. ሩም ማጥፋት (Delete Room) service
  Future<bool> deleteRoom(String roomId) async {
    try {
      // 1. አይዲው ባዶ አለመሆኑን ማረጋገጥ
      if (roomId.isEmpty) {
        debugPrint("Delete Error: Room ID is empty");
        return false;
      }
      final response = await _dio.delete('/rooms/$roomId');
      // 2. ሰርቨሩ ስኬታማ ከሆነ 200 ወይም 204 ይመልሳል
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      debugPrint("Delete Room Server Error: ${e.response?.data}");
      return false;
    } catch (e) {
      debugPrint("Delete Room Unexpected Error: $e");
      return false;
    }
  }

}
