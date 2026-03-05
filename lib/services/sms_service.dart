class SmsService {
  // ቴሌብር አጭር ቁጥር (Official Short Code)
  static const String telebirrSender = '127';

  static bool isTargetSender(String? address) {
    if (address == null) return false;
    
    // የላኪውን አድራሻ እናፅዳ (Space ካለ እና ወደ ትልቅ ሆሄያት)
    final String cleanAddress = address.trim().toUpperCase();

    // 1. ለቴሌብር ማረጋገጫ (ልክ "127" ከሆነ ወይም በ "127" የሚያልቅ ከሆነ)
    // አንዳንድ የኢትዮጵያ ስልኮች ላይ አድራሻው በ +251127 ሊመጣ ስለሚችል endsWith ጠቃሚ ነው
    if (cleanAddress == telebirrSender || cleanAddress.endsWith(telebirrSender)) {
      return true;
    }

    // 2. በስም "TELEBIRR" ተብሎ ከመጣ (አልፎ አልፎ በአድራሻ ቦታ ስሙ ሊመጣ ስለሚችል)
    if (cleanAddress.contains('TELEBIRR')) {
      return true;
    }

    // 3. ቁጥር ብቻ አውጥተን እንፈትሽ (ለምሳሌ "+251 127" ወደ "251127" ይቀየራል)
    final numericAddress = address.replaceAll(RegExp(r'[^\d]'), '');
    if (numericAddress == telebirrSender || numericAddress.endsWith(telebirrSender)) {
      return true;
    }

    return false;
  }
}