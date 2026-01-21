import 'package:another_telephony/telephony.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'services/api_service.dart';
import 'services/sms_service.dart';
import 'screens/main_scaffold.dart';
const String syncTaskName = "com.eyu.smssync.periodicTask";

// Background handler must stay at top-level
@pragma('vm:entry-point')
Future<bool> telephonyBackgroundHandler(SmsMessage message) async {
  if (SmsService.isTargetSender(message.address)) {
    return await ApiService().sendSmsToBackend(
      message.address ?? '',
      message.body ?? '',
    );
  }
  return false;
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  Workmanager().initialize(callbackDispatcher);
  Workmanager().registerPeriodicTask(
    "1",
    syncTaskName,
    frequency: const Duration(minutes: 15),
  );

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MainScaffold(),
  ));
}