import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  // Callback so HomeScreen can refresh the name after saving
  final VoidCallback? onNameUpdated;

  const ProfileScreen({super.key, this.onNameUpdated});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final nameController = TextEditingController();
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmNewPasswordController = TextEditingController();

  final userService = UserService();
  final authService = AuthService();

  bool isLoadingName = false;
  bool isLoadingPassword = false;
  bool obscureCurrent = true;
  bool obscureNew = true;
  bool obscureConfirm = true;

  // Inline errors
  String? nameError;
  String? currentPasswordError;
  String? newPasswordError;
  String? confirmPasswordError;

  @override
  void initState() {
    super.initState();
    _loadCurrentName();
  }

  Future<void> _loadCurrentName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final name = await userService.getUserName(uid);
    if (mounted && name != null) {
      nameController.text = name;
    }
  }

  Future<void> _saveName() async {
    setState(() => nameError = null);

    if (nameController.text.trim().isEmpty) {
      setState(() => nameError = 'Name cannot be empty.');
      return;
    }

    setState(() => isLoadingName = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      await userService.updateUserName(
        uid: user.uid,
        name: nameController.text.trim(),
        email: user.email ?? '',
      );

      if (!mounted) return;

      // Tell HomeScreen to reload the name
      widget.onNameUpdated?.call();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(_successSnackBar('Name updated successfully!'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        _errorSnackBar(e.toString().replaceAll('Exception: ', '')),
      );
    }

    if (mounted) setState(() => isLoadingName = false);
  }

  Future<void> _changePassword() async {
    setState(() {
      currentPasswordError = null;
      newPasswordError = null;
      confirmPasswordError = null;
    });

    bool valid = true;

    if (currentPasswordController.text.trim().isEmpty) {
      setState(() => currentPasswordError = 'Current password is required.');
      valid = false;
    }

    if (newPasswordController.text.trim().isEmpty) {
      setState(() => newPasswordError = 'New password is required.');
      valid = false;
    } else if (newPasswordController.text.trim().length < 6) {
      setState(
        () => newPasswordError = 'Password must be at least 6 characters.',
      );
      valid = false;
    }

    if (confirmNewPasswordController.text.trim().isEmpty) {
      setState(
        () => confirmPasswordError = 'Please confirm your new password.',
      );
      valid = false;
    } else if (newPasswordController.text.trim() !=
        confirmNewPasswordController.text.trim()) {
      setState(() => confirmPasswordError = 'Passwords do not match.');
      valid = false;
    }

    if (!valid) return;

    setState(() => isLoadingPassword = true);

    try {
      await authService.changePassword(
        currentPassword: currentPasswordController.text.trim(),
        newPassword: newPasswordController.text.trim(),
      );

      if (!mounted) return;

      // Clear password fields after success
      currentPasswordController.clear();
      newPasswordController.clear();
      confirmNewPasswordController.clear();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(_successSnackBar('Password changed successfully!'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        _errorSnackBar(e.toString().replaceAll('Exception: ', '')),
      );
    }

    if (mounted) setState(() => isLoadingPassword = false);
  }

  @override
  void dispose() {
    nameController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmNewPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar ──────────────────────────────────────────────
              Center(
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.15),
                  child: Text(
                    nameController.text.isNotEmpty
                        ? nameController.text[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Center(
                child: Text(
                  user?.email ?? '',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),

              const SizedBox(height: 32),

              // ── Display Name Section ─────────────────────────────────
              _sectionLabel('Display Name'),
              const SizedBox(height: 12),

              _buildField(
                controller: nameController,
                label: 'Your Name',
                error: nameError,
                onChanged: (_) {
                  setState(() => nameError = null);
                  // Rebuild avatar letter live
                  setState(() {});
                },
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoadingName ? null : _saveName,
                  child: isLoadingName
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Name'),
                ),
              ),

              const SizedBox(height: 36),
              const Divider(),
              const SizedBox(height: 24),

              // ── Change Password Section ──────────────────────────────
              _sectionLabel('Change Password'),
              const SizedBox(height: 12),

              _buildField(
                controller: currentPasswordController,
                label: 'Current Password',
                error: currentPasswordError,
                obscure: obscureCurrent,
                onChanged: (_) => setState(() => currentPasswordError = null),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureCurrent ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => obscureCurrent = !obscureCurrent),
                ),
              ),

              const SizedBox(height: 16),

              _buildField(
                controller: newPasswordController,
                label: 'New Password',
                error: newPasswordError,
                obscure: obscureNew,
                onChanged: (_) => setState(() => newPasswordError = null),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureNew ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => obscureNew = !obscureNew),
                ),
              ),

              const SizedBox(height: 16),

              _buildField(
                controller: confirmNewPasswordController,
                label: 'Confirm New Password',
                error: confirmPasswordError,
                obscure: obscureConfirm,
                onChanged: (_) => setState(() => confirmPasswordError = null),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => obscureConfirm = !obscureConfirm),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoadingPassword ? null : _changePassword,
                  child: isLoadingPassword
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Change Password'),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // Section header label
  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  // Reusable field with inline red error
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? error,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: error != null ? Colors.red : Colors.grey.shade400,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: error != null
                    ? Colors.red
                    : Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
            suffixIcon: suffixIcon,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              error,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Snackbar helpers ──────────────────────────────────────────────────────────

SnackBar _errorSnackBar(String message) {
  return SnackBar(
    content: Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    ),
    backgroundColor: Colors.red.shade700,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    margin: const EdgeInsets.all(16),
    duration: const Duration(seconds: 4),
  );
}

SnackBar _successSnackBar(String message) {
  return SnackBar(
    content: Row(
      children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    ),
    backgroundColor: Colors.green.shade700,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    margin: const EdgeInsets.all(16),
    duration: const Duration(seconds: 3),
  );
}
