class SmsService {
  // ቴሌብር አጭር ቁጥር እና የንግድ ባንክ ስም
  static const String telebirrSender = '127';
  static const String cbeSender = 'CBE';

  static bool isTargetSender(String? address) {
    if (address == null) return false;
    
    // የላኪውን አድራሻ ወደ ትልቅ ሆሄያት እንቀይረው (Cbe, cbe, CBE ሁሉንም እንዲያነብ)
    final String cleanAddress = address.trim().toUpperCase();

    // 1. ለቴሌብር ማረጋገጫ (127)
    if (cleanAddress == telebirrSender || cleanAddress.endsWith(telebirrSender)) {
      return true;
    }

    // 2. ለኢትዮጵያ ንግድ ባንክ ማረጋገጫ (CBE)
    if (cleanAddress == cbeSender || cleanAddress.contains(cbeSender)) {
      return true;
    }

    // 3. ቁጥር ብቻ ከሆነ (አንዳንድ ስልኮች ላይ በቁጥር ሊመጣ ስለሚችል)
    final numericAddress = address.replaceAll(RegExp(r'[^\d]'), '');
    if (numericAddress == telebirrSender || numericAddress.endsWith(telebirrSender)) {
      return true;
    }

    return false;
  }
}