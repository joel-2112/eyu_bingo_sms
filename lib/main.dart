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
Future<void> sendSmsToBackend(String sender, String message) async {
  try {
    print(
      'Sending SMS to backend - Sender: $sender, Message length: ${message.length}',
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
    print('Backend response: ${response.statusCode} - ${response.data}');
  } catch (e) {
    print('Error sending to backend: $e');
    if (e is DioException) {
      print(
        'Dio error details: ${e.response?.statusCode} - ${e.response?.data}',
      );
      print('Request URL: ${e.requestOptions.uri}');
    }
    // Don't rethrow - let caller handle it if needed
  }
}

// 1. Telephony Background Handler (SMS ሲመጣ ወዲያው የሚነሳ)
@pragma('vm:entry-point')
Future<bool> telephonyBackgroundHandler(SmsMessage message) async {
  try {
    print('Background SMS received from: ${message.address}');
    if (message.address != null &&
        (message.address == targetSender ||
            message.address!.endsWith(targetSender))) {
      print('Processing SMS from target sender: ${message.address}');
      await sendSmsToBackend(message.address!, message.body ?? '');
      return true;
    }
    print('SMS ignored - not from target sender');
    return false;
  } catch (e) {
    print('Error in background handler: $e');
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
  bool _hasPermissions = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  void _initApp() async {
    print('Requesting SMS permissions...');
    bool? permissionsGranted = await telephony.requestSmsPermissions;
    print('SMS Permissions granted: $permissionsGranted');

    setState(() {
      _hasPermissions = permissionsGranted == true;
    });

    if (permissionsGranted == true) {
      print('Starting SMS listener...');
      _startListening();
    } else {
      print(
        'SMS permissions not granted! Please grant permissions in settings.',
      );
    }
    _loadSyncedSms();
  }

  Future<void> _checkAndRequestPermissions() async {
    print('Checking SMS permissions...');
    bool? permissionsGranted = await telephony.requestSmsPermissions;
    print('SMS Permissions granted: $permissionsGranted');

    setState(() {
      _hasPermissions = permissionsGranted == true;
    });

    if (permissionsGranted == true && !_isListening) {
      _startListening();
    }
  }

  void _startListening() {
    if (_isListening) {
      print('SMS listener already active');
      return;
    }

    print('Setting up SMS listener...');
    try {
      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          print('Foreground SMS received from: ${message.address}');
          print('SMS body: ${message.body}');
          if (message.address != null &&
              (message.address == targetSender ||
                  message.address!.endsWith(targetSender))) {
            print(
              'Processing foreground SMS from target sender: ${message.address}',
            );
            sendSmsToBackend(message.address!, message.body ?? '')
                .then((_) {
                  print('SMS sent to backend, refreshing list...');
                  _loadSyncedSms();
                })
                .catchError((error) {
                  print('Error sending SMS to backend: $error');
                });
          } else {
            print(
              'SMS ignored - sender ${message.address} is not $targetSender',
            );
          }
        },
        onBackgroundMessage: telephonyBackgroundHandler,
      );
      setState(() {
        _isListening = true;
      });
      print('SMS listener started successfully');
    } catch (e) {
      print('Error starting SMS listener: $e');
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> _loadSyncedSms() async {
    setState(() => _isLoading = true);
    try {
      final response = await dio.get(
        syncSmsUrl,
        queryParameters: {'secret_key': secretKey},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List data = response.data['data'];
        setState(() {
          _syncedSmsList = data
              .map((json) => SyncedSms.fromJson(json))
              .toList();
        });
      }
    } catch (e) {
      print("Fetch error: $e");
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
          title: const Text("127 SMS Sync Active"),
          actions: [
            IconButton(
              icon: Icon(_hasPermissions ? Icons.check_circle : Icons.warning),
              color: _hasPermissions ? Colors.green : Colors.orange,
              onPressed: _checkAndRequestPermissions,
              tooltip: _hasPermissions
                  ? 'Permissions granted'
                  : 'Request permissions',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadSyncedSms,
              tooltip: 'Refresh list',
            ),
          ],
        ),
        body: Column(
          children: [
            if (!_hasPermissions)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.orange.shade100,
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: const Text(
                        'SMS permissions not granted. Tap to request.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _checkAndRequestPermissions,
                      child: const Text('Grant'),
                    ),
                  ],
                ),
              ),
            if (_hasPermissions && !_isListening)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade100,
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'SMS listener not active. Please restart the app.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadSyncedSms,
                      child: _syncedSmsList.isEmpty
                          ? const Center(
                              child: Text(
                                "ምንም የተላከ መልዕክት የለም።\nአፑ በጀርባ እየሰራ ነው...",
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
                                      color: sms.isUsed
                                          ? Colors.grey
                                          : Colors.green,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
