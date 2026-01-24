import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/transaction.dart';

class WithdrawRequestScreen extends StatefulWidget {
  const WithdrawRequestScreen({super.key});

  @override
  State<WithdrawRequestScreen> createState() => _WithdrawRequestScreenState();
}

class _WithdrawRequestScreenState extends State<WithdrawRequestScreen> {
  final ApiService _apiService = ApiService();

  List<WithdrawTransaction> _allWithdrawals = [];
  List<WithdrawTransaction> _filteredWithdrawals = [];

  bool _isLoading = true;
  String _searchQuery = "";
  String _selectedFilter = "All";

  final Set<int> _updatingIds = {};

  // Custom Indigo Colors
  final Color primaryIndigo = const Color(0xFF3F51B5);
  final Color darkIndigo = const Color(0xFF1A237E);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.fetchWithdrawals();
      setState(() {
        _allWithdrawals = data;
        _applyFilters();
      });
    } catch (e) {
      _showSnackBar("Error loading data: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredWithdrawals = _allWithdrawals.where((tx) {
        final matchesSearch =
            tx.user.username.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            tx.user.phoneNumber.contains(_searchQuery);

        final matchesStatus =
            _selectedFilter == "All" ||
            tx.status.toLowerCase() == _selectedFilter.toLowerCase();

        return matchesSearch && matchesStatus;
      }).toList();
      _filteredWithdrawals.sort((a, b) => b.id.compareTo(a.id));
    });
  }

  Future<void> _handleUpdate(int id, String status, String note) async {
    setState(() => _updatingIds.add(id));
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = await _apiService.updateWithdrawStatus(
      id,
      status,
      note: note,
    );
    if (mounted) Navigator.pop(context);

    if (success) {
      _showSnackBar(
        "✅ Transaction Updated: ${status.toUpperCase()}",
        Colors.teal,
      );
      await _loadData();
    } else {
      _showSnackBar("❌ Update Failed.", Colors.red);
    }
    if (mounted) setState(() => _updatingIds.remove(id));
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text(
          "Admin Payouts",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        centerTitle: false,
        backgroundColor: darkIndigo, // Customized Indigo
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMiniSummary(),
          _buildSearchAndFilterBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: primaryIndigo,
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: primaryIndigo),
                    )
                  : _filteredWithdrawals.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                        bottom: 100,
                        top: 10,
                        left:12,
                        right: 12
                      ),
                      itemCount: _filteredWithdrawals.length,
                      itemBuilder: (context, index) =>
                          _buildCompactCard(_filteredWithdrawals[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSummary() {
    final pendingCount = _allWithdrawals
        .where((tx) => tx.status == 'pending')
        .length;
    final totalPendingAmount = _allWithdrawals
        .where((tx) => tx.status == 'pending')
        .fold(0.0, (sum, item) => sum + item.amount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: darkIndigo,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "PENDING VOLUME",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
              Text(
                "${totalPendingAmount.toStringAsFixed(2)} ETB",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "$pendingCount Pending",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryIndigo.withOpacity(0.2)),
              ),
              child: TextField(
                onChanged: (v) {
                  _searchQuery = v;
                  _applyFilters();
                },
                decoration: InputDecoration(
                  hintText: "Search Username or Phone...",
                  hintStyle: const TextStyle(fontSize: 14),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: primaryIndigo,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryIndigo.withOpacity(0.2)),
            ),
            child: DropdownButton<String>(
              value: _selectedFilter,
              underline: const SizedBox(),
              icon: Icon(Icons.filter_list, size: 20, color: primaryIndigo),
              items: ["All", "Pending", "Success", "Failed"]
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s, style: const TextStyle(fontSize: 14)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() => _selectedFilter = v!);
                _applyFilters();
              },
            ),
          ),
        ],
      ),
    );
  }

Widget _buildCompactCard(WithdrawTransaction tx) {
  bool isPending = tx.status.toLowerCase() == 'pending';
  bool isUpdating = _updatingIds.contains(tx.id);
  Color statusColor = isPending
      ? Colors.orange
      : (tx.status == 'success' ? Colors.teal : Colors.red);

  return Container(
    margin: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
      border: Border.all(color: Colors.indigo.withOpacity(0.1)),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: isPending && !isUpdating ? () => _showActionSheet(tx) : null,
        child: Padding(
          padding: const EdgeInsets.all(10), 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primaryIndigo.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        tx.user.username[0].toUpperCase(),
                        style: TextStyle(
                          color: primaryIndigo,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              tx.user.username,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildBalanceTypeBadge(tx.balanceType),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tx.user.phoneNumber,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${tx.amount} ETB",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: darkIndigo,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildStatusPill(tx.status, statusColor),
                    ],
                  ),
                ],
              ),
              
              if (tx.description.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          size: 16, color: primaryIndigo),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tx.description,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey[800],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy | hh:mm a').format(DateTime.now()),
                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                  ),
                  if (isPending)
                    Icon(Icons.arrow_forward_ios, 
                         size: 12, color: Colors.indigo[600]),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
  Widget _buildStatusPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildBalanceTypeBadge(String type) {
    bool isReal = type.toLowerCase() == 'real';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: isReal
            ? Colors.green.withOpacity(0.1)
            : Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isReal ? "REAL" : "BONUS",
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: isReal ? Colors.green : Colors.purple,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No transactions found",
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

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
            top: 12,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Review Payout",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: darkIndigo,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildChoiceChip(
                      "Approve",
                      Icons.check_circle,
                      selectedStatus == 'success',
                      Colors.teal,
                      () {
                        setDialogState(() {
                          selectedStatus = 'success';
                          noteController.text = "Approved by Admin";
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildChoiceChip(
                      "Reject",
                      Icons.cancel,
                      selectedStatus == 'failed',
                      Colors.red,
                      () {
                        setDialogState(() {
                          selectedStatus = 'failed';
                          noteController.text = "Rejected: Contact Support";
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: "DESCRIPTION / NOTE",
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedStatus == 'success'
                        ? Colors.teal
                        : Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _showConfirmation(tx, selectedStatus, noteController.text);
                  },
                  child: Text("CONFIRM ${selectedStatus.toUpperCase()}"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConfirmation(WithdrawTransaction tx, String status, String note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          status == 'success' ? "Confirm Approval" : "Confirm Rejection",
        ),
        content: Text(
          "Action: ${status.toUpperCase()}\nUser: ${tx.user.username}\nAmount: ${tx.amount} ETB\n\nAre you sure?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: TextStyle(color: primaryIndigo)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleUpdate(tx.id, status, note);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'success' ? Colors.teal : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("PROCEED"),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(
    String label,
    IconData icon,
    bool isSelected,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey[400]),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
