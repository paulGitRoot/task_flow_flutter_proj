import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final authService = AuthService();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;

  // Inline error strings — null means no error shown
  String? nameError;
  String? emailError;
  String? passwordError;
  String? confirmError;

  // Validates all fields and returns true if everything passes
  bool _validate() {
    setState(() {
      nameError = null;
      emailError = null;
      passwordError = null;
      confirmError = null;
    });

    bool valid = true;

    if (nameController.text.trim().isEmpty) {
      setState(() => nameError = 'Name is required.');
      valid = false;
    }

    final email = emailController.text.trim();
    if (email.isEmpty) {
      setState(() => emailError = 'Email is required.');
      valid = false;
    } else if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() => emailError = 'Enter a valid email address.');
      valid = false;
    }

    if (passwordController.text.trim().isEmpty) {
      setState(() => passwordError = 'Password is required.');
      valid = false;
    } else if (passwordController.text.trim().length < 6) {
      setState(() => passwordError = 'Password must be at least 6 characters.');
      valid = false;
    }

    if (confirmPasswordController.text.trim().isEmpty) {
      setState(() => confirmError = 'Please confirm your password.');
      valid = false;
    } else if (passwordController.text.trim() !=
        confirmPasswordController.text.trim()) {
      setState(() => confirmError = 'Passwords do not match.');
      valid = false;
    }

    return valid;
  }

  Future<void> register() async {
    if (!_validate()) return;

    setState(() => isLoading = true);

    try {
      await authService.register(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        _successSnackBar('Account created successfully! Welcome 🎉'),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        _errorSnackBar(e.toString().replaceAll('Exception: ', '')),
      );
    }

    if (mounted) setState(() => isLoading = false);
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Name
              _buildField(
                controller: nameController,
                label: 'Full Name',
                error: nameError,
                onChanged: (_) => setState(() => nameError = null),
              ),

              const SizedBox(height: 16),

              // Email
              _buildField(
                controller: emailController,
                label: 'Email',
                error: emailError,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() => emailError = null),
              ),

              const SizedBox(height: 16),

              // Password
              _buildField(
                controller: passwordController,
                label: 'Password',
                error: passwordError,
                obscure: obscurePassword,
                onChanged: (_) => setState(() => passwordError = null),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => obscurePassword = !obscurePassword),
                ),
              ),

              const SizedBox(height: 16),

              // Confirm Password
              _buildField(
                controller: confirmPasswordController,
                label: 'Confirm Password',
                error: confirmError,
                obscure: obscureConfirm,
                onChanged: (_) => setState(() => confirmError = null),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => obscureConfirm = !obscureConfirm),
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : register,
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Reusable field with inline error text below it
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

