import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import '../models/synced_sms.dart';
import '../services/api_service.dart';
import '../services/sms_service.dart';
import '../main.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Telephony telephony = Telephony.instance;
  final ApiService _apiService = ApiService();
  List<SyncedSms> _syncedSmsList = [];
  bool _isLoading = false;
  bool _isListening = false;

  final Color primaryIndigo = const Color(0xFF3F51B5);
  final Color backgroundGrey = const Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  void _initApp() async {
    bool? permissionsGranted = await telephony.requestSmsPermissions;
    if (permissionsGranted == true) {
      _startListening();
    }
    _loadSyncedSms();
  }

  void _startListening() {
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        if (SmsService.isTargetSender(message.address)) {
          _apiService.sendSmsToBackend(message.address ?? '', message.body ?? '')
              .then((success) {
            if (success) _loadSyncedSms();
          });
        }
      },
      onBackgroundMessage: telephonyBackgroundHandler,
    );
    setState(() => _isListening = true);
  }

  Future<void> _loadSyncedSms() async {
    setState(() => _isLoading = true);
    try {
      final list = await _apiService.fetchSyncedSms();
      setState(() => _syncedSmsList = list);
    } catch (e) {
      debugPrint("Fetch error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Synced Messages",
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isListening ? "Listener Active" : "Listener Inactive",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: primaryIndigo),
            onPressed: _loadSyncedSms,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryIndigo))
          : RefreshIndicator(
              color: primaryIndigo,
              onRefresh: _loadSyncedSms,
              child: _syncedSmsList.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: _syncedSmsList.length,
                      itemBuilder: (context, index) => ModernSmsCard(
                        sms: _syncedSmsList[index],
                        primaryIndigo: primaryIndigo,
                      ),
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "ምንም የተላከ መልዕክት የለም",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Text("Pull down to refresh", style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}

// --- አዲሱ የካርድ ኮድ (Stateful ስለሆነ መዘርጋት ይችላል) ---
class ModernSmsCard extends StatefulWidget {
  final SyncedSms sms;
  final Color primaryIndigo;

  const ModernSmsCard({super.key, required this.sms, required this.primaryIndigo});

  @override
  State<ModernSmsCard> createState() => _ModernSmsCardState();
}

class _ModernSmsCardState extends State<ModernSmsCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                color: widget.sms.isUsed ? Colors.grey[400] : widget.primaryIndigo,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "TXID: ${widget.sms.transactionId}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _isExpanded = !_isExpanded),
                            child: Icon(
                              _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: widget.primaryIndigo,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // የጽሁፉ ሁኔታ እዚህ ይወሰናል
                      Text(
                        widget.sms.messageContent,
                        style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.4),
                        maxLines: _isExpanded ? null : 2, // ከተዘረጋ ገደብ የለውም
                        overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: widget.sms.isUsed ? Colors.grey[100] : widget.primaryIndigo.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.sms.isUsed ? "Used" : "Active",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: widget.sms.isUsed ? Colors.grey[600] : widget.primaryIndigo,
                              ),
                            ),
                          ),
                          Text(
                            widget.sms.dateReceived,
                            style: TextStyle(color: Colors.grey[500], fontSize: 11),
                          ),
                        ],
                      ),
                      if (_isExpanded) ...[
                        const Divider(height: 24),
                        Row(
                          children: [
                            Icon(Icons.payments_outlined, size: 16, color: widget.primaryIndigo),
                            const SizedBox(width: 4),
                            Text(
                              "Amount: ${widget.sms.amount} ETB",
                              style: TextStyle(fontWeight: FontWeight.bold, color: widget.primaryIndigo, fontSize: 14),
                            ),
                          ],
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}