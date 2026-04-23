import 'package:flutter/material.dart';
import 'dart:async';
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
    // FIX: Check if scroll controller has clients before accessing position
    if (!_scrollController.hasClients) return;
    
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreBackend) {
      _loadMoreUsers();
    }
  }

  Future<Map<String, dynamic>> _fetchData({required int page}) async {
    // FIX: Always pass the correct parameters
    if (_isSearchMode && _searchQuery.isNotEmpty) {
      print('🔍 Searching: query="$_searchQuery", page=$page, sort=$_sortBy');
      return await _apiService.searchUsers(
        query: _searchQuery,
        page: page,
        limit: _pageSize,
        sortBy: _sortBy,
      );
    } else {
      print('📋 Getting all users: page=$page, sort=$_sortBy');
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
        _users = []; // Clear list immediately on refresh
      });
    }

    try {
      final response = await _fetchData(page: _currentPage);
      
      if (!mounted) return; // Check if widget is still mounted
      
      print('📊 Response data count: ${response['data']?.length ?? 0}');
      print('📊 Pagination: ${response['pagination']}');
      
      setState(() {
        if (refresh) {
          _users = List.from(response['data'] ?? []);
        } else {
          final newUsers = List.from(response['data'] ?? []);
          // Prevent duplicates by checking IDs
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
      print('❌ Error fetching users: $e');
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        // Don't decrement page on error
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
    
    // FIX: Wait for widget to rebuild before scrolling
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
      body: _isLoading
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
                    itemCount: _users.length + (_hasMoreBackend ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _users.length) {
                        return _buildLoadMoreIndicator();
                      }
                      return _buildUserTile(_users[index]);
                    },
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
    final telegramId = user['telegram_id']?.toString() ?? "—";
    final mainBal = _formatBalance(user['balance']);
    final bonusBal = _formatBalance(user['bonus_balance']);
    final coinBal = user['coins_balance']?.toString() ?? "0";
    final gamesWon = user['totalGamesWon'] ?? 0;
    final ticketsBought = user['totalTicketsBought'] ?? 0;
    final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : "?";

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.8),
        ),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to user detail
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      "$phone · TG: $telegramId",
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _buildBalPill("$mainBal ETB", const Color(0xFF3F51B5),
                            const Color(0xFFE8EAF6)),
                        _buildBalPill("$bonusBal ETB", const Color(0xFF7B1FA2),
                            const Color(0xFFF3E5F5)),
                        _buildBalPill("$coinBal coins", const Color(0xFFF57F17),
                            const Color(0xFFFFF8E1)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatBadge(
                    "Won $gamesWon",
                    const Color(0xFF00695C),
                    const Color(0xFFE0F2F1),
                  ),
                  const SizedBox(height: 5),
                  _buildStatBadge(
                    "Tix $ticketsBought",
                    const Color(0xFFE65100),
                    const Color(0xFFFFF3E0),
                  ),
                ],
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatBadge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
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