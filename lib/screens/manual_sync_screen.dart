import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ManualSyncScreen extends StatefulWidget {
  const ManualSyncScreen({super.key});

  @override
  State<ManualSyncScreen> createState() => _ManualSyncScreenState();
}

class _ManualSyncScreenState extends State<ManualSyncScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  // መጀመሪያ በ 127 እንዲጀምር (እንደ ምርጫህ 'CBE' ማድረግም ትችላለህ)
  final TextEditingController _senderController = TextEditingController(
    text: '127',
  );
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _secretKeyController = TextEditingController(
    text: 'sms127eyuebingo2025',
  );

  bool _isSubmitting = false;

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      final success = await _apiService.sendSmsToBackend(
        _senderController.text.trim(),
        _messageController.text.trim(),
      );

      setState(() => _isSubmitting = false);

      if (success) {
        _messageController.clear();
        if (mounted) {
          _showStatusSnackBar(
            '✅ SMS manually synced successfully!',
            Colors.green,
          );
        }
      } else {
        if (mounted) {
          _showStatusSnackBar(
            '❌ Failed to sync SMS. Check connection.',
            Colors.redAccent,
          );
        }
      }
    }
  }

  void _showStatusSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryIndigo = Color(0xFF3F51B5);
    const backgroundGrey = Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        title: const Text(
          "Manual SMS Entry",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryIndigo.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bolt, color: primaryIndigo, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              "Manual Sync",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Enter the details below to manually push a missed SMS to the backend.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- ፈጣን መምረጫ (127 ወይም CBE) ---
                    Row(
                      children: [
                        _buildQuickSelectChip("127", primaryIndigo),
                        const SizedBox(width: 10),
                        _buildQuickSelectChip("CBE", primaryIndigo),
                      ],
                    ),
                    const SizedBox(height: 15),

                    _buildInputField(
                      controller: _senderController,
                      label: "Sender ID (127 or CBE)",
                      icon: Icons.account_balance_wallet_outlined,
                      primaryColor: primaryIndigo,
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      controller: _secretKeyController,
                      label: "System Secret Key",
                      icon: Icons.vpn_key_outlined,
                      primaryColor: primaryIndigo,
                      isPassword: true,
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      controller: _messageController,
                      label: "Full SMS Content",
                      icon: Icons.message_outlined,
                      primaryColor: primaryIndigo,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryIndigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Push to Backend",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ፈጣን መምረጫ Chip Builder
  Widget _buildQuickSelectChip(String label, Color color) {
    bool isSelected = _senderController.text == label;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : color,
          fontWeight: FontWeight.bold,
        ),
      ),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: color.withOpacity(0.1),
      onSelected: (bool selected) {
        setState(() {
          _senderController.text = label;
        });
      },
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color primaryColor,
    int maxLines = 1,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          obscureText: isPassword,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[50],
            prefixIcon: Icon(icon, color: primaryColor, size: 20),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
          ),
          validator: (value) =>
              value!.isEmpty ? "This field is required" : null,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _senderController.dispose();
    _messageController.dispose();
    _secretKeyController.dispose();
    super.dispose();
  }
}
