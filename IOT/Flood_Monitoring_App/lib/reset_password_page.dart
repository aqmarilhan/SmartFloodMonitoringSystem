import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final emailController = TextEditingController();
  final codeController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool codeSent = false;

  @override
  void dispose() {
    emailController.dispose();
    codeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String? getPasswordError(String password) {
    List<String> missing = [];

    if (password.length < 10) {
      missing.add("at least 10 characters");
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      missing.add("at least 1 uppercase letter");
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      missing.add("at least 1 number");
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_]'))) {
      missing.add("at least 1 special character");
    }

    if (missing.isEmpty) return null;

    if (missing.length == 1) {
      return "Password must contain ${missing[0]}.";
    }

    final lastItem = missing.removeLast();
    return "Password must contain ${missing.join(", ")} and $lastItem.";
  }

  String extractCode(String input) {
    final trimmed = input.trim();
    if (trimmed.contains("oobCode=")) {
      try {
        final uri = Uri.parse(trimmed);
        return uri.queryParameters["oobCode"] ?? trimmed;
      } catch (_) {
        return trimmed;
      }
    }
    return trimmed;
  }

  Future<void> sendCode() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      showMessage("Please enter your email address.");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() {
        codeSent = true;
      });
      showMessage("Password reset email sent. Please check your inbox for the link/code.");
    } on FirebaseAuthException catch (e) {
      String message = "An error occurred.";
      if (e.code == "invalid-email") {
        message = "The email address is invalid.";
      } else if (e.code == "user-not-found") {
        message = "No account found with this email.";
      } else {
        message = e.message ?? message;
      }
      showMessage(message);
    } catch (e) {
      showMessage("Error: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> performReset() async {
    final rawCode = codeController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (rawCode.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      showMessage("Please fill in all fields.");
      return;
    }

    if (password != confirmPassword) {
      showMessage("Passwords do not match.");
      return;
    }

    final passwordError = getPasswordError(password);
    if (passwordError != null) {
      showMessage(passwordError);
      return;
    }

    setState(() {
      isLoading = true;
    });

    final oobCode = extractCode(rawCode);

    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: oobCode,
        newPassword: password,
      );
      showMessage("Password reset successful! You can now log in.");
      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = "Failed to reset password.";
      if (e.code == "expired-action-code") {
        message = "The reset code has expired. Please request a new one.";
      } else if (e.code == "invalid-action-code") {
        message = "The reset code is invalid. Please copy the code/link correctly.";
      } else if (e.code == "user-disabled") {
        message = "This account has been disabled.";
      } else if (e.code == "user-not-found") {
        message = "User not found.";
      } else if (e.code == "weak-password") {
        message = "Password is too weak.";
      } else {
        message = e.message ?? message;
      }
      showMessage(message);
    } catch (e) {
      showMessage("Error: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Color getBackgroundColor(bool isDarkMode) {
    return isDarkMode ? const Color(0xFF0F172A) : Colors.lightBlue.shade50;
  }

  Color getCardColor(bool isDarkMode) {
    return isDarkMode ? const Color(0xFF1E293B) : Colors.white;
  }

  Color getMainTextColor(bool isDarkMode) {
    return isDarkMode ? Colors.white : Colors.black87;
  }

  Color getSubTextColor(bool isDarkMode) {
    return isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    required bool isDarkMode,
    bool obscureText = false,
    Widget? suffixIcon,
    String? hintText,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: getMainTextColor(isDarkMode)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        hintStyle: TextStyle(color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400, fontSize: 13),
        labelStyle: TextStyle(color: getSubTextColor(isDarkMode)),
        prefixIcon: Icon(
          prefixIcon,
          color: isDarkMode ? const Color(0xFF06B6D4) : const Color(0xFF0284C7),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDarkMode
            ? const Color(0xFF0F172A).withOpacity(0.5)
            : Colors.grey.shade100,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: isDarkMode ? const Color(0xFF06B6D4) : const Color(0xFF0284C7),
            width: 2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: getBackgroundColor(isDarkMode),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: getBackgroundColor(isDarkMode),
        foregroundColor: getMainTextColor(isDarkMode),
        title: const Text("Reset Password"),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(28.0),
            decoration: BoxDecoration(
              color: getCardColor(isDarkMode),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.08)
                    : Colors.white.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.4)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: isDarkMode
                      ? const Color(0xFF06B6D4).withOpacity(0.15)
                      : const Color(0xFF0284C7).withOpacity(0.12),
                  child: Icon(
                    Icons.lock_reset_rounded,
                    size: 44,
                    color: isDarkMode ? const Color(0xFF06B6D4) : const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "Recover Account",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: getMainTextColor(isDarkMode),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  codeSent
                      ? "Enter the code or link from the reset email and set your new password."
                      : "Enter your registered email address to receive a secure password reset link.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Form Fields
                if (!codeSent) ...[
                  buildTextField(
                    controller: emailController,
                    label: "Email Address",
                    prefixIcon: Icons.email_outlined,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : sendCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? const Color(0xFF06B6D4) : const Color(0xFF0284C7),
                        foregroundColor: isDarkMode ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: isDarkMode ? Colors.black : Colors.white,
                              ),
                            )
                          : const Text(
                              "Send Reset Link",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ),
                ] else ...[
                  buildTextField(
                    controller: codeController,
                    label: "Reset Code or Link",
                    hintText: "Paste code or full email link here",
                    prefixIcon: Icons.vpn_key_outlined,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 16),
                  buildTextField(
                    controller: passwordController,
                    label: "New Password",
                    prefixIcon: Icons.lock_outline_rounded,
                    isDarkMode: isDarkMode,
                    obscureText: obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      onPressed: () => setState(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 16),
                  buildTextField(
                    controller: confirmPasswordController,
                    label: "Confirm New Password",
                    prefixIcon: Icons.lock_outline_rounded,
                    isDarkMode: isDarkMode,
                    obscureText: obscureConfirmPassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      onPressed: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : performReset,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? const Color(0xFF06B6D4) : const Color(0xFF0284C7),
                        foregroundColor: isDarkMode ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: isDarkMode ? Colors.black : Colors.white,
                              ),
                            )
                          : const Text(
                              "Update Password",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => codeSent = false),
                    child: Text(
                      "Resend Reset Email",
                      style: TextStyle(
                        color: isDarkMode ? const Color(0xFF06B6D4) : const Color(0xFF0284C7),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
