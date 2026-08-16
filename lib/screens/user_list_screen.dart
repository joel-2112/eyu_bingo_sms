import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  static const int _pageSize = 10;
  static const primaryIndigo = Color(0xFF3F51B5);

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSearchMode = false;
  bool _isExporting = false;

  List<dynamic> _users = [];
  
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  bool _hasMoreBackend = true;

  String _searchQuery = "";
  String _sortBy = "createdAt";
  
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreBackend) {
      _loadMoreUsers();
    }
  }

  Future<Map<String, dynamic>> _fetchData({required int page}) async {
    if (_isSearchMode && _searchQuery.isNotEmpty) {
      return await _apiService.searchUsers(
        query: _searchQuery,
        page: page,
        limit: _pageSize,
        sortBy: _sortBy,
      );
    } else {
      return await _apiService.getAllUsers(
        page: page,
        limit: _pageSize,
        sortBy: _sortBy,
      );
    }
  }

  Future<void> _fetchUsers({bool refresh = true}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _users = [];
      });
    }

    try {
      final response = await _fetchData(page: _currentPage);
      
      if (!mounted) return;
      
      setState(() {
        if (refresh) {
          _users = List.from(response['data'] ?? []);
        } else {
          final newUsers = List.from(response['data'] ?? []);
          final existingIds = _users.map((u) => u['id']).toSet();
          for (var user in newUsers) {
            if (!existingIds.contains(user['id'])) {
              _users.add(user);
              existingIds.add(user['id']);
            }
          }
        }
        
        _totalPages = response['pagination']?['totalPages'] ?? 1;
        _totalItems = response['pagination']?['totalItems'] ?? 0;
        _hasMoreBackend = _currentPage < _totalPages;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        if (!refresh) {
          _currentPage--;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _loadMoreUsers() async {
    if (!_hasMoreBackend || _isLoadingMore) return;
    
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    
    await _fetchUsers(refresh: false);
  }

  Future<void> _exportUsersToCsv() async {
    setState(() => _isExporting = true);
    try {
      final data = await _apiService.exportUsersCsv();
      List<int> bytes;
      if (data is List<int>) {
        bytes = data;
      } else if (data is String) {
        bytes = data.codeUnits;
      } else {
        bytes = data.toString().codeUnits;
      }

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/users_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("✅ Users exported successfully! File ready to share."),
          backgroundColor: Colors.teal,
          action: SnackBarAction(
            label: "SHARE",
            textColor: Colors.white,
            onPressed: () {
              Share.shareXFiles([XFile(filePath)], text: "Users Export CSV");
            },
          ),
        ),
      );
      await Share.shareXFiles([XFile(filePath)], text: "Users Export CSV");
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Export failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final trimmedValue = value.trim();
      if (trimmedValue != _searchQuery) {
        setState(() {
          _searchQuery = trimmedValue;
          _isSearchMode = trimmedValue.isNotEmpty;
        });
        _fetchUsers(refresh: true);
      }
    });
  }

  void _onSortChanged(String value) {
    if (value == _sortBy) return;
    
    setState(() {
      _sortBy = value;
    });
    _fetchUsers(refresh: true);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _users.isNotEmpty) {
        try {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } catch (e) {
          print('Scroll animation error: $e');
        }
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = "";
      _isSearchMode = false;
    });
    _fetchUsers(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text(
          "Users Management",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          _isExporting
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryIndigo,
                      ),
                    ),
                  ),
                )
              : TextButton.icon(
                  onPressed: _exportUsersToCsv,
                  icon: const Icon(Icons.download_rounded, size: 18, color: primaryIndigo),
                  label: const Text(
                    "Export",
                    style: TextStyle(
                      color: primaryIndigo,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
          if (_isSearchMode)
            IconButton(
              onPressed: _clearSearch,
              icon: const Icon(Icons.clear, color: Colors.red),
            ),
          IconButton(
            onPressed: () => _fetchUsers(refresh: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Search by name or phone...",
                          hintStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: primaryIndigo, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: _clearSearch,
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildCountBadge(),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSortChip("Latest", "createdAt"),
                      const SizedBox(width: 6),
                      _buildSortChip("Top Balance", "balance"),
                      const SizedBox(width: 6),
                      _buildSortChip("Top Bonus", "bonus_balance"),
                      const SizedBox(width: 6),
                      _buildSortChip("Top Coins", "coins_balance"),
                      const SizedBox(width: 6),
                      _buildSortChip("Most Tickets", "tickets"),
                      const SizedBox(width: 6),
                      _buildSortChip("Most Wins", "won"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryIndigo))
            : _users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isSearchMode ? Icons.search_off : Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isSearchMode 
                              ? 'No users found for "$_searchQuery"'
                              : "ምንም ተጠቃሚ አልተገኘም",
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        if (_isSearchMode)
                          TextButton(
                            onPressed: _clearSearch,
                            child: const Text("Clear search"),
                          ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      await _fetchUsers(refresh: true);
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.only(bottom: bottomInset + 90, top: 8),
                      itemCount: _users.length + (_hasMoreBackend ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _users.length) {
                          return _buildLoadMoreIndicator();
                        }
                        return _buildUserTile(_users[index]);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildCountBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isSearchMode 
            ? Colors.orange.withOpacity(0.1)
            : primaryIndigo.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$_totalItems",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: _isSearchMode ? Colors.orange : primaryIndigo,
            ),
          ),
          Text(
            _isSearchMode ? "Found" : "Total Users",
            style: TextStyle(
              fontSize: 9,
              color: (_isSearchMode ? Colors.orange : primaryIndigo).withOpacity(0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () => _onSortChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryIndigo : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryIndigo : Colors.grey[300]!,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              const Icon(Icons.check, size: 14, color: Colors.white),
            if (isSelected)
              const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(dynamic user) {
    final username = user['username']?.toString() ?? "No Username";
    final phone = user['phone_number']?.toString() ?? "—";
    final mainBal = _formatBalance(user['balance']);
    final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : "?";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showUserDetailBottomSheet(user),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primaryIndigo.withOpacity(0.1),
                child: Text(
                  firstLetter,
                  style: const TextStyle(
                    color: primaryIndigo,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF1A1A2E),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildBalPill("$mainBal ETB", primaryIndigo, primaryIndigo.withOpacity(0.08)),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserDetailBottomSheet(dynamic user) {
    final username = user['username']?.toString() ?? "No Username";
    final phone = user['phone_number']?.toString() ?? "—";
    final telegramId = user['telegram_id']?.toString() ?? "—";
    final userId = user['id']?.toString() ?? user['_id']?.toString() ?? "—";
    final mainBal = _formatBalance(user['balance']);
    final bonusBal = _formatBalance(user['bonus_balance']);
    final coinBal = user['coins_balance']?.toString() ?? "0";
    final gamesWon = user['totalGamesWon']?.toString() ?? "0";
    final ticketsBought = user['totalTicketsBought']?.toString() ?? "0";
    final createdAt = user['createdAt']?.toString() ?? "—";
    final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : "?";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 20,
          right: 20,
          top: 12,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: primaryIndigo.withOpacity(0.1),
                    child: Text(
                      firstLetter,
                      style: const TextStyle(
                        color: primaryIndigo,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                        Text(
                          "User ID: $userId",
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              const Text(
                "CONTACT & ACCOUNT",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              _buildDetailRow(Icons.phone_outlined, "Phone Number", phone),
              _buildDetailRow(Icons.send_rounded, "Telegram ID", telegramId),
              _buildDetailRow(Icons.calendar_today_outlined, "Registered On", createdAt),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              const Text(
                "BALANCES & STATS",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      "Main Balance",
                      "$mainBal ETB",
                      primaryIndigo,
                      primaryIndigo.withOpacity(0.08),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      "Bonus Balance",
                      "$bonusBal ETB",
                      const Color(0xFF7B1FA2),
                      const Color(0xFFF3E5F5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      "Coins Balance",
                      "$coinBal Coins",
                      const Color(0xFFE65100),
                      const Color(0xFFFFF3E0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      "Games Won",
                      gamesWon,
                      const Color(0xFF00695C),
                      const Color(0xFFE0F2F1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      "Tickets",
                      ticketsBought,
                      Colors.blueGrey,
                      Colors.blueGrey.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryIndigo),
          const SizedBox(width: 10),
          Text(
            "$label:",
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.8), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: textColor),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatBalance(dynamic balance) {
    if (balance == null) return "0.00";
    final num = double.tryParse(balance.toString()) ?? 0;
    return num.toStringAsFixed(2);
  }

  Widget _buildBalPill(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _isLoadingMore
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: primaryIndigo,
                  strokeWidth: 2.5,
                ),
              )
            : _hasMoreBackend
                ? OutlinedButton.icon(
                    onPressed: _loadMoreUsers,
                    icon: const Icon(Icons.expand_more_rounded, size: 18),
                    label: Text(
                      "Load more (Page ${_currentPage + 1} of $_totalPages)",
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryIndigo,
                      side: const BorderSide(color: primaryIndigo, width: 0.8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                  )
                : const SizedBox.shrink(),
      ),
    );
  }
}