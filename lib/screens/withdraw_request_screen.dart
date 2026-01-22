import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/transaction.dart';

class WithdrawRequestScreen extends StatefulWidget {
  const WithdrawRequestScreen({super.key});

  @override
  State<WithdrawRequestScreen> createState() => _WithdrawRequestScreenState();
}

class _WithdrawRequestScreenState extends State<WithdrawRequestScreen> {
  final ApiService _apiService = ApiService();
  List<WithdrawTransaction> _withdrawals = [];
  bool _isLoading = true;
  
  // Track specific transaction IDs being updated to show local loading
  final Set<int> _updatingIds = {};

  final Color primaryIndigo = const Color(0xFF3F51B5);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- Logic Methods ---

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.fetchWithdrawals();
      setState(() => _withdrawals = data);
    } catch (e) {
      _showSnackBar("Error loading data: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUpdate(int id, String status, String note) async {
    setState(() => _updatingIds.add(id));

    // Show persistent overlay loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = await _apiService.updateWithdrawStatus(id, status, note: note);
    
    if (mounted) Navigator.pop(context); // Remove overlay

    if (success) {
      _showSnackBar("✅ Transaction marked as ${status.toUpperCase()}", Colors.teal);
      await _loadData();
    } else {
      _showSnackBar("❌ Server Error (500). Please check logs.", Colors.red);
    }

    if (mounted) setState(() => _updatingIds.remove(id));
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // --- UI Components ---

  @override
  Widget build(BuildContext context) {
    final pendingItems = _withdrawals.where((tx) => tx.status == 'pending').toList();
    final pendingCount = pendingItems.length;
    final totalPendingAmount = pendingItems.fold(0.0, (sum, item) => sum + item.amount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Payout Management", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded), 
            onPressed: _isLoading ? null : _loadData
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: primaryIndigo,
        child: _isLoading 
            ? _buildLoadingState()
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildSummarySection(pendingCount, totalPendingAmount)),
                  _withdrawals.isEmpty
                      ? _buildEmptyState()
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildWithdrawCard(_withdrawals[index]),
                              childCount: _withdrawals.length,
                            ),
                          ),
                        ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryIndigo, strokeWidth: 3),
          const SizedBox(height: 16),
          Text("Fetching requests...", style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text("No withdrawal requests found", style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(int count, double total) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryIndigo, primaryIndigo.withBlue(200)]
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: primaryIndigo.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("TOTAL PENDING", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                child: Text("$count Requests", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text("${total.toStringAsFixed(2)} ETB", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildWithdrawCard(WithdrawTransaction tx) {
    bool isPending = tx.status.toLowerCase() == 'pending';
    bool isUpdating = _updatingIds.contains(tx.id);
    Color statusColor = isPending ? Colors.orange : (tx.status == 'success' ? Colors.teal : Colors.red);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            leading: CircleAvatar(
              backgroundColor: primaryIndigo.withOpacity(0.1),
              child: Text(tx.user.username[0].toUpperCase(), style: TextStyle(color: primaryIndigo, fontWeight: FontWeight.bold)),
            ),
            title: Row(
              children: [
                Text(tx.user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                // Visual badge for Real vs Bonus
                _buildBalanceTypeBadge(tx.balanceType),
              ],
            ),
            subtitle: Text(tx.user.phoneNumber, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            trailing: Text("${tx.amount} ETB", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: primaryIndigo)),
          ),
          
          if (tx.description.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: Colors.grey[50], border: Border(left: BorderSide(color: statusColor, width: 4))),
              child: Text(tx.description, style: TextStyle(fontSize: 12, color: Colors.blueGrey[600])),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusPill(tx.status.toUpperCase(), statusColor),
                if (isPending)
                  ElevatedButton(
                    onPressed: isUpdating ? null : () => _showActionSheet(tx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryIndigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: isUpdating 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("REVIEW"),
                  )
                else
                   Icon(tx.status == 'success' ? Icons.check_circle : Icons.cancel, color: statusColor, size: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceTypeBadge(String type) {
    bool isReal = type.toLowerCase() == 'real';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isReal ? Colors.green.withOpacity(0.1) : Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4)
      ),
      child: Text(
        isReal ? "REAL" : "BONUS", 
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isReal ? Colors.green : Colors.purple)
      ),
    );
  }

  Widget _buildStatusPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  // --- Bottom Sheet & Logic ---

  void _showActionSheet(WithdrawTransaction tx) {
    String selectedStatus = 'success';
    final noteController = TextEditingController(text: "Approved by Admin");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 12, left: 24, right: 24
          ),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Text("Payout for ${tx.user.username}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              Text("Amount: ${tx.amount} ETB", style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildChoiceChip("Approve", Icons.check_circle, selectedStatus == 'success', Colors.teal, () {
                    setDialogState(() {
                      selectedStatus = 'success';
                      noteController.text = "Approved by Admin";
                    });
                  })),
                  const SizedBox(width: 12),
                  Expanded(child: _buildChoiceChip("Reject", Icons.cancel, selectedStatus == 'failed', Colors.red, () {
                    setDialogState(() {
                      selectedStatus = 'failed';
                      noteController.text = "Rejected: Contact Support";
                    });
                  })),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: "INTERNAL NOTE",
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedStatus == 'success' ? Colors.teal : Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Close sheet
                    _showConfirmation(tx, selectedStatus, noteController.text);
                  },
                  child: Text("PROCEED TO ${selectedStatus.toUpperCase()}"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Final Confirmation Step
  void _showConfirmation(WithdrawTransaction tx, String status, String note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(status == 'success' ? "Confirm Payout?" : "Confirm Rejection?"),
        content: Text("Are you sure you want to ${status == 'success' ? 'approve' : 'reject and refund'} ${tx.amount} ETB for ${tx.user.username}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("BACK")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleUpdate(tx.id, status, note);
            }, 
            child: Text("YES, CONFIRM", style: TextStyle(color: status == 'success' ? Colors.teal : Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(String label, IconData icon, bool isSelected, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : Colors.grey.withOpacity(0.2), width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey[400]),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}