import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/synced_sms.dart';
import '../models/transaction.dart';

class ApiService {
  static const String baseUrl = 'https://api.asinaye.eyuelkassahun.com';
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

Future<Map<String, dynamic>> getAllUsers({
  int page = 1, 
  int limit = 10,
  String sortBy = 'createdAt',
}) async {
  try {
    final response = await _dio.get(
      '/users',
      queryParameters: {
        'page': page,
        'limit': limit,
        'sortBy': sortBy,
      },
    );
    return response.data;
  } catch (e) {
    rethrow;
  }
}

  Future<Map<String, dynamic>> searchUsers({
    required String query,
    int page = 1,
    int limit = 10,
    String sortBy = 'createdAt',
  }) async {
    try {
      final response = await _dio.get(
        '/users/search',
        queryParameters: {
          'query': query,
          'page': page,
          'limit': limit,
          'sortBy': sortBy,
        },
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // 5.5. Export ALL users to CSV
  Future<dynamic> exportUsersCsv() async {
    // 1. Try server endpoint first
    try {
      final response = await _dio.get(
        '/users/export-csv',
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) => true,
        ),
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data;
      }
    } catch (_) {}

    // 2. Fallback: Fetch ALL users from database across all pages
    final List<dynamic> allUsers = await fetchAllUsersForExport();
    final csvString = _generateUsersCsv(allUsers);
    return csvString.codeUnits;
  }

  Future<List<dynamic>> fetchAllUsersForExport() async {
    final List<dynamic> allUsers = [];
    int currentPage = 1;
    int totalPages = 1;

    do {
      try {
        final res = await getAllUsers(page: currentPage, limit: 100);
        final List pageData = res['data'] ?? [];
        allUsers.addAll(pageData);

        totalPages = res['pagination']?['totalPages'] ?? 1;
        currentPage++;
      } catch (e) {
        debugPrint("Error fetching users page $currentPage: $e");
        break;
      }
    } while (currentPage <= totalPages);

    return allUsers;
  }

  String _generateUsersCsv(List<dynamic> users) {
    final buffer = StringBuffer();
    buffer.writeln('ID,Username,Phone Number,Telegram ID,Balance,Bonus Balance,Coins Balance,Games Won,Tickets Bought,Created At');
    
    for (var u in users) {
      final id = _escapeCsv(u['id'] ?? u['_id'] ?? '');
      final username = _escapeCsv(u['username'] ?? '');
      final phone = _escapeCsv(u['phone_number'] ?? u['phone'] ?? '');
      final telegramId = _escapeCsv(u['telegram_id'] ?? '');
      final balance = _escapeCsv(u['balance'] ?? 0);
      final bonus = _escapeCsv(u['bonus_balance'] ?? 0);
      final coins = _escapeCsv(u['coins_balance'] ?? 0);
      final won = _escapeCsv(u['totalGamesWon'] ?? 0);
      final tickets = _escapeCsv(u['totalTicketsBought'] ?? 0);
      final createdAt = _escapeCsv(u['createdAt'] ?? '');

      buffer.writeln('$id,$username,$phone,$telegramId,$balance,$bonus,$coins,$won,$tickets,$createdAt');
    }
    return buffer.toString();
  }

  String _escapeCsv(dynamic val) {
    final str = val.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
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
