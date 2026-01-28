import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _allUsers = []; // ኦሪጅናል ዳታ
  List<dynamic> _filteredUsers = []; // የተጣራ እና የተደረደረ ዳታ
  
  String _searchQuery = "";
  String _sortBy = "createdAt"; // መጀመሪያ በጊዜ እንዲደረደር

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final data = await _apiService.getAllUsers();
      setState(() {
        _allUsers = data;
        _filteredUsers = data;
        _isLoading = false;
        _applyFiltersAndSort(); 
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("የተጠቃሚዎችን መረጃ ማምጣት አልተቻለም")),
        );
      }
    }
  }

  void _applyFiltersAndSort() {
    setState(() {
      // 1. መፈለጊያ (Search Logic)
      _filteredUsers = _allUsers.where((user) {
        final name = (user['username'] ?? "").toString().toLowerCase();
        final phone = (user['phone_number'] ?? "").toString();
        return name.contains(_searchQuery.toLowerCase()) || phone.contains(_searchQuery);
      }).toList();

      // 2. መደርደሪያ (Sorting Logic)
      _filteredUsers.sort((a, b) {
        switch (_sortBy) {
          case 'balance':
            double balA = double.tryParse(a['balance']?.toString() ?? "0") ?? 0;
            double balB = double.tryParse(b['balance']?.toString() ?? "0") ?? 0;
            return balB.compareTo(balA);
          case 'tickets':
            int tixA = a['totalTicketsBought'] ?? 0;
            int tixB = b['totalTicketsBought'] ?? 0;
            return tixB.compareTo(tixA);
          case 'won':
            int wonA = a['totalGamesWon'] ?? 0;
            int wonB = b['totalGamesWon'] ?? 0;
            return wonB.compareTo(wonA);
          default: // Latest
            return (b['createdAt'] ?? "").toString().compareTo((a['createdAt'] ?? "").toString());
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryIndigo = Color(0xFF3F51B5);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Users Management", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(onPressed: _fetchUsers, icon: const Icon(Icons.refresh_rounded))
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) {
                    _searchQuery = value;
                    _applyFiltersAndSort();
                  },
                  decoration: InputDecoration(
                    hintText: "በስም ወይም በስልክ ይፈልጉ...",
                    prefixIcon: const Icon(Icons.search, color: primaryIndigo),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSortChip("Latest", "createdAt"),
                      const SizedBox(width: 8),
                      _buildSortChip("Top Balance", "balance"),
                      const SizedBox(width: 8),
                      _buildSortChip("Most Tickets", "tickets"),
                      const SizedBox(width: 8),
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
          : _filteredUsers.isEmpty
              ? const Center(child: Text("ምንም ተጠቃሚ አልተገኘም"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) => _buildUserCard(_filteredUsers[index]),
                ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    bool isSelected = _sortBy == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _sortBy = value;
          _applyFiltersAndSort();
        }
      },
      selectedColor: const Color(0xFF3F51B5),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildUserCard(dynamic user) {
    String username = user['username']?.toString() ?? "No Username";
    String phoneNumber = user['phone_number']?.toString() ?? "No Number";
    String mainBalance = user['balance']?.toString() ?? "0.00";
    String bonusBalance = user['bonus_balance']?.toString() ?? "0.00";
    String firstLetter = username.isNotEmpty ? username[0].toUpperCase() : "?";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFF3F51B5).withOpacity(0.1),
                child: Text(
                  firstLetter,
                  style: const TextStyle(color: Color(0xFF3F51B5), fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      phoneNumber,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatBadge("Won: ${user['totalGamesWon'] ?? 0}", Colors.teal),
                  const SizedBox(height: 5),
                  _buildStatBadge("Tix: ${user['totalTicketsBought'] ?? 0}", Colors.orange),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 0.5),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBalanceInfo("Main Balance", "$mainBalance ETB", Colors.indigo),
              _buildBalanceInfo("Bonus Balance", "$bonusBalance ETB", Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceInfo(String label, String amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
        Text(amount, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildStatBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}