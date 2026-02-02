import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ManageRoomsScreen extends StatefulWidget {
  const ManageRoomsScreen({super.key});

  @override
  State<ManageRoomsScreen> createState() => _ManageRoomsScreenState();
}

class _ManageRoomsScreenState extends State<ManageRoomsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _rooms = [];

  // ለፎርሙ የሚያስፈልጉ Controllers
  final _nameController = TextEditingController();
  final _feeController = TextEditingController();
  final _playersController = TextEditingController();
  final _commController = TextEditingController();
  final _agentCommController = TextEditingController();
  final _agentIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  Future<void> _fetchRooms() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getAllRooms();
      setState(() {
        _rooms = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Rooms ማምጣት አልተቻለም", Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  void _showCreateRoomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // ከበስተጀርባ ያለውን ግልጽ ለማድረግ
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 24,
          right: 24,
          top: 12,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // የላይኛው መጎተቻ መስመር (Drag Handle)
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 25),

              const Text(
                "Create New Room",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: Color(0xFF1A237E),
                ),
              ),
              const Text(
                "ሁሉንም መረጃዎች በትክክል ይሙሉ",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 25),

              // የፎርሙ ክፍሎች
              _buildProfessionalField(
                _nameController,
                "Room Name",
                Icons.drive_file_rename_outline,
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildProfessionalField(
                      _feeController,
                      "Entry Fee",
                      Icons.payments,
                      isNumber: true,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildProfessionalField(
                      _playersController,
                      "Max Players",
                      Icons.groups,
                      isNumber: true,
                    ),
                  ),
                ],
              ),
              _buildProfessionalField(
                _commController,
                "Admin Commission (%)",
                Icons.pie_chart,
                isNumber: true,
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, thickness: 0.5),
              ),

              _buildProfessionalField(
                _agentCommController,
                "Agent Comm (%)",
                Icons.badge,
                isNumber: true,
              ),
              _buildProfessionalField(
                _agentIdController,
                "Agent Telegram ID",
                Icons.alternate_email,
              ),

              const SizedBox(height: 30),

              // ዘመናዊ በተን
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3F51B5).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3F51B5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _submitRoom,
                  child: const Text(
                    "ሩም ፍጠር",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitRoom() async {
    if (_nameController.text.isEmpty || _feeController.text.isEmpty) {
      _showSnackBar("እባክዎ አስፈላጊ መረጃዎችን ያሟሉ", Colors.orange);
      return;
    }

    // ፐርሰንት ከሆነ (ለምሳሌ 35 ካለ ተጠቃሚው) ወደ 0.35 መቀየር አለበት
    double comm = (double.tryParse(_commController.text) ?? 35) / 100;
    double? agentComm = _agentCommController.text.isNotEmpty
        ? (double.tryParse(_agentCommController.text)! / 100)
        : null;

    final success = await _apiService.createRoom(
      name: _nameController.text,
      entryFee: double.tryParse(_feeController.text) ?? 0.0,
      maxPlayers: int.tryParse(_playersController.text) ?? 100,
      commissionRate: comm,
      agentCommissionRate: agentComm,
      agentTelegramId: _agentIdController.text.trim(),
    );

    if (success) {
      if (mounted) {
        Navigator.pop(context);
        _clearControllers();
        _fetchRooms();
        _showSnackBar("ሩም በትክክል ተፈጥሯል", Colors.green);
      }
    } else {
      _showSnackBar("መፍጠር አልተቻለም (400) - ዳታውን ያረጋግጡ", Colors.red);
    }
  }

  void _clearControllers() {
    _nameController.clear();
    _feeController.clear();
    _playersController.clear();
    _commController.clear();
    _agentCommController.clear();
    _agentIdController.clear();
  }

  Future<void> _deleteRoom(String id) async {
    // 1. አይዲው ባዶ መሆኑን ቼክ እናድርግ
    if (id.isEmpty) {
      _showSnackBar("ስህተት፡ የሩም መለያ (ID) አልተገኘም", Colors.red);
      return;
    }

    final success = await _apiService.deleteRoom(id);

    if (success) {
      if (mounted) {
        _fetchRooms();
        _showSnackBar("ሩም ተሰርዟል", Colors.blueGrey);
      }
    } else {
      // ስህተት ካለ ለተጠቃሚው ማሳወቅ
      _showSnackBar("ሩሙን መሰረዝ አልተቻለም (Error 400)", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text(
          "Manage Rooms",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showCreateRoomSheet,
            icon: const Icon(
              Icons.add_circle_outline,
              color: Color(0xFF3F51B5),
              size: 28,
            ),
            tooltip: "Add Room",
          ),
          IconButton(onPressed: _fetchRooms, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
          ? const Center(child: Text("ምንም ሩም የለም"))
          : ListView.builder(
              padding: const EdgeInsets.only(
                right: 16,
                left: 16,
                top: 10,
                bottom: 80,
              ),
              itemCount: _rooms.length,
              itemBuilder: (context, index) {
                final room = _rooms[index];
                return _buildRoomCard(room);
              },
            ),
    );
  }

  Widget _buildRoomCard(dynamic room) {
    final String roomId = room['id']?.toString() ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.withOpacity(0.1),
          child: const Icon(Icons.casino, color: Colors.indigo),
        ),
        title: Text(
          room['name'] ?? "Unknown",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "Entry: ${room['entry_fee']} ETB | Players: ${room['max_players']}",
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () {
            _confirmDelete(roomId);
          },
        ),
      ),
    );
  }

  void _confirmDelete(String roomId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("ሩም ማጥፊያ"),
        content: const Text("እርግጠኛ ነዎት ይህንን ሩም ማጥፋት ይፈልጋሉ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ተመለስ", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context); // ዳያሎጉን መዝጋት
              _deleteRoom(roomId); // ወደ ዋናው የዲሊት ፋንክሽን መላክ
            },
            child: const Text("አጥፋ", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: Icon(icon, color: const Color(0xFF3F51B5), size: 22),
              filled: true,
              fillColor: const Color(0xFFF5F6FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: Color(0xFF3F51B5),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ],
      ),
    );
  }
}
