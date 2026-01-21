import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'withdraw_request_screen.dart';
import 'manual_sync_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const WithdrawRequestScreen(),
    const ManualSyncScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryIndigo = Color(0xFF3F51B5);
    // የስክሪኑን ስፋት ለማወቅ
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      // extendBody አስፈላጊ የሚሆነው ባሩ ግልጽ (transparent) እንዲሆን ሲፈለግ ነው
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          // Margin ን ከስክሪኑ ስፋት አንጻር ተለዋዋጭ እናድርገው
          margin: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05, 
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              backgroundColor: Colors.transparent,
              selectedItemColor: primaryIndigo,
              unselectedItemColor: Colors.grey[400],
              showSelectedLabels: true,
              showUnselectedLabels: false,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              items: [
                _buildNavItem(Icons.sync_alt_rounded, 'Messages', 0),
                _buildNavItem(Icons.account_balance_wallet_rounded, 'Withdraw', 1),
                _buildNavItem(Icons.add_box_rounded, 'Manual', 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, String label, int index) {
    const primaryIndigo = Color(0xFF3F51B5);
    bool isSelected = _selectedIndex == index;

    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryIndigo.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(
          icon,
          size: isSelected ? 26 : 22,
        ),
      ),
      label: label,
    );
  }
}