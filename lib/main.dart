import 'package:another_telephony/telephony.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:dio/dio.dart';

// --- Constants ---
const String backendUrl = 'https://eyu-bingo.onrender.com/sms/receive';
const String syncSmsUrl = 'https://eyu-bingo.onrender.com/sms/sync-sms';
const String secretKey = 'sms127eyuebingo2025';
const String targetSender = '127';
const String syncTaskName = "com.eyu.smssync.periodicTask";

final Dio dio = Dio();

// --- SMS Model ---
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

// --- Global Functions (Top Level) ---

// ዳታ ወደ ሰርቨር መላኪያ
Future<bool> sendSmsToBackend(String sender, String message) async {
  try {
    print(
      '📤 Sending SMS to backend - Sender: $sender, Message length: ${message.length}',
    );
    final response = await dio.post(
      backendUrl,
      data: {'sender': sender, 'message': message, 'secret_key': secretKey},
      options: Options(
        headers: {'Content-Type': 'application/json'},
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    print('✅ Backend response: ${response.statusCode} - ${response.data}');
    return true;
  } catch (e) {
    print('❌ Error sending to backend: $e');
    if (e is DioException) {
      print('   Status: ${e.response?.statusCode}');
      print('   Data: ${e.response?.data}');
      print('   URL: ${e.requestOptions.uri}');
    }
    return false;
  }
}

// Check if sender matches target (handles different phone number formats)
bool isTargetSender(String? address) {
  if (address == null) {
    print('   ⚠️  Address is null');
    return false;
  }

  print('   🔍 Checking sender: "$address" against target "$targetSender"');

  // Direct match
  if (address == targetSender) {
    print('   ✅ Direct match found');
    return true;
  }

  // Ends with match
  if (address.endsWith(targetSender)) {
    print('   ✅ Ends with match found');
    return true;
  }

  // Remove any non-digit characters for comparison
  final cleanAddress = address.replaceAll(RegExp(r'[^\d]'), '');
  print('   🔍 Cleaned address: "$cleanAddress"');

  // Check cleaned address
  if (cleanAddress == targetSender || cleanAddress.endsWith(targetSender)) {
    print('   ✅ Cleaned address match found');
    return true;
  }

  print('   ❌ No match found');
  return false;
}

// 1. Telephony Background Handler (SMS ሲመጣ ወዲያው የሚነሳ)
@pragma('vm:entry-point')
Future<bool> telephonyBackgroundHandler(SmsMessage message) async {
  try {
    print('📱 Background SMS received from: ${message.address}');
    print(
      '   Body preview: ${(message.body ?? '').substring(0, (message.body?.length ?? 0) > 50 ? 50 : (message.body?.length ?? 0))}...',
    );

    if (isTargetSender(message.address)) {
      print('✅ Target sender matched! Processing...');
      final success = await sendSmsToBackend(
        message.address ?? '',
        message.body ?? '',
      );
      return success;
    } else {
      print(
        '⏭️  SMS ignored - sender "${message.address}" is not "$targetSender"',
      );
      return false;
    }
  } catch (e) {
    print('❌ Error in background handler: $e');
    return false;
  }
}

// 2. Workmanager Callback (አፑ በጀርባ በህይወት እንዲቆይ የሚረዳ)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Workmanager periodic check running...");
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Workmanager ማስጀመር
  Workmanager().initialize(callbackDispatcher);
  Workmanager().registerPeriodicTask(
    "1",
    syncTaskName,
    frequency: const Duration(minutes: 15), // በየ 15 ደቂቃው አፑን ያነቃቃል
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final Telephony telephony = Telephony.instance;
  List<SyncedSms> _syncedSmsList = [];
  bool _isLoading = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  void _initApp() async {
    print('🔐 Requesting SMS permissions...');
    bool? permissionsGranted = await telephony.requestSmsPermissions;
    print('   Permissions granted: $permissionsGranted');

    if (permissionsGranted == true) {
      print('✅ Permissions granted, starting SMS listener...');
      _startListening();
    } else {
      print(
        '❌ Permissions NOT granted! Please grant SMS permissions in settings.',
      );
    }
    _loadSyncedSms();
  }

  void _startListening() {
    print('👂 Setting up SMS listener...');
    try {
      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          print('📨 Foreground SMS received from: ${message.address}');
          print('   Body: ${message.body}');

          if (isTargetSender(message.address)) {
            print('✅ Target sender matched! Sending to backend...');
            sendSmsToBackend(message.address ?? '', message.body ?? '')
                .then((success) {
                  if (success) {
                    print('✅ SMS sent successfully, refreshing list...');
                    _loadSyncedSms();
                  } else {
                    print('❌ Failed to send SMS to backend');
                  }
                })
                .catchError((error) {
                  print('❌ Error in sendSmsToBackend: $error');
                });
          } else {
            print(
              '⏭️  SMS ignored - sender "${message.address}" is not "$targetSender"',
            );
          }
        },
        onBackgroundMessage: telephonyBackgroundHandler,
      );
      print('✅ SMS listener started successfully');
      setState(() => _isListening = true);
    } catch (e) {
      print('❌ Error starting SMS listener: $e');
      setState(() => _isListening = false);
    }
  }

  Future<void> _loadSyncedSms() async {
    setState(() => _isLoading = true);
    try {
      print('📥 Fetching synced SMS list...');
      final response = await dio.get(
        syncSmsUrl,
        queryParameters: {'secret_key': secretKey},
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      print('   Response status: ${response.statusCode}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List data = response.data['data'];
        print('   Found ${data.length} synced SMS');
        setState(() {
          _syncedSmsList = data
              .map((json) => SyncedSms.fromJson(json))
              .toList();
        });
      } else {
        print('   Unexpected response: ${response.data}');
      }
    } catch (e) {
      print("❌ Fetch error: $e");
      if (e is DioException) {
        print('   Status: ${e.response?.statusCode}');
        print('   Data: ${e.response?.data}');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Text("127 SMS Sync"),
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadSyncedSms,
              tooltip: 'Refresh SMS list',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadSyncedSms,
                child: _syncedSmsList.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isListening ? Icons.check_circle : Icons.error,
                                size: 48,
                                color: _isListening
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _isListening
                                    ? "ምንም የተላከ መልዕክት የለም።\nአፑ በጀርባ እየሰራ ነው..."
                                    : "SMS Listener not active!\nCheck permissions and restart app.",
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Listening for SMS from: $targetSender",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _syncedSmsList.length,
                        itemBuilder: (context, index) {
                          final sms = _syncedSmsList[index];
                          return Card(
                            margin: const EdgeInsets.all(8),
                            child: ListTile(
                              title: Text(
                                "TXID: ${sms.transactionId}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
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
                        },
                      ),
              ),
      ),
    );
  }
}
