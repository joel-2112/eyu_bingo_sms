class SmsService {
  static const String targetSender = '127';

  static bool isTargetSender(String? address) {
    if (address == null) return false;
    if (address == targetSender) return true;
    if (address.endsWith(targetSender)) return true;
    
    final cleanAddress = address.replaceAll(RegExp(r'[^\d]'), '');
    return cleanAddress == targetSender || cleanAddress.endsWith(targetSender);
  }
}