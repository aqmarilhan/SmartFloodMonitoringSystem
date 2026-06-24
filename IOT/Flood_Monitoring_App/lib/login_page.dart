import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'signup_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

final String databaseURL =
    "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app";

bool isValidEmail(String email) {
  return RegExp(
    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
  ).hasMatch(email);
}

Future<bool> isEmailRegistered(String email) async {
  final database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: databaseURL,
  );

  final snapshot = await database.ref("Users").get();

  if (!snapshot.exists || snapshot.value == null) {
    return false;
  }

  final users = Map<dynamic, dynamic>.from(snapshot.value as Map);

  for (final user in users.values) {
    final userData = Map<dynamic, dynamic>.from(user);
    final registeredEmail =
        userData["email"]?.toString().trim().toLowerCase() ?? "";

    if (registeredEmail == email.trim().toLowerCase()) {
      return true;
    }
  }

  return false;
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  // Biometrics parameters
  final LocalAuthentication auth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  bool _biometricsAvailable = false;
  bool _hasSavedCredentials = false;
  bool _enableBiometricLogin = true;

  @override
  void initState() {
    super.initState();
    _initBiometricsAndCredentials();
  }

  Future<void> _initBiometricsAndCredentials() async {
    await _checkBiometricAvailability();
    await _loadSavedCredentialsFlag();

    // Trigger biometric login if credentials exist and biometrics are supported
    if (_hasSavedCredentials && _canCheckBiometrics && _biometricsAvailable) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && emailController.text.isNotEmpty && !isLoading) {
          loginWithBiometrics();
        }
      });
    }
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await auth.canCheckBiometrics;
      final isDeviceSupported = await auth.isDeviceSupported();
      if (!mounted) return;
      setState(() {
        _canCheckBiometrics = isAvailable && isDeviceSupported;
      });
      if (_canCheckBiometrics) {
        final availableBiometrics = await auth.getAvailableBiometrics();
        if (!mounted) return;
        setState(() {
          _biometricsAvailable = availableBiometrics.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint("Error checking biometrics: $e");
    }
  }

  Future<void> _loadSavedCredentialsFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasEmail = prefs.containsKey("saved_email");
      final hasPassword = prefs.containsKey("saved_password");
      if (!mounted) return;
      setState(() {
        _hasSavedCredentials = hasEmail && hasPassword;
        if (hasEmail) {
          final savedEmail = prefs.getString("saved_email") ?? "";
          final decryptedEmail = _decryptData(savedEmail);
          if (decryptedEmail.isNotEmpty) {
            emailController.text = decryptedEmail;
          }
        }
      });
    } catch (e) {
      debugPrint("Error loading biometric credentials flag: $e");
    }
  }

  // Cryptography for Security FYP (AES-128)
  String _encryptData(String plainText) {
    final key = enc.Key.fromUtf8('my32lengthsupersecretnooneknows1'); // 32 chars
    final iv = enc.IV.fromUtf8('1234567890123456'); // 16 chars static IV
    final encrypter = enc.Encrypter(enc.AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  String _decryptData(String encryptedBase64) {
    try {
      final key = enc.Key.fromUtf8('my32lengthsupersecretnooneknows1');
      final iv = enc.IV.fromUtf8('1234567890123456'); // 16 chars static IV
      final encrypter = enc.Encrypter(enc.AES(key));
      return encrypter.decrypt(enc.Encrypted.fromBase64(encryptedBase64), iv: iv);
    } catch (e) {
      // Fallback: If decryption fails, the value is likely legacy plaintext.
      // Return it as-is so it can log in and be automatically upgraded.
      return encryptedBase64;
    }
  }

  Future<void> loginWithBiometrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmailEnc = prefs.getString("saved_email") ?? "";
      final savedPasswordEnc = prefs.getString("saved_password") ?? "";

      if (savedEmailEnc.isEmpty || savedPasswordEnc.isEmpty) {
        showMessage("No biometric credentials registered. Please login with password first.");
        return;
      }

      final authenticated = await auth.authenticate(
        localizedReason: 'Scan fingerprint or Face ID to login securely',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!authenticated) return;

      setState(() {
        isLoading = true;
      });

      final email = _decryptData(savedEmailEnc);
      final password = _decryptData(savedPasswordEnc);

      if (email.isEmpty || password.isEmpty) {
        showMessage("Decryption failed. Please login with password again.");
        setState(() {
          isLoading = false;
        });
        return;
      }

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user!.reload();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && user.email != "admin@gmail.com" && !user.emailVerified) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() {
          isLoading = false;
        });
        showMessage("Email is not verified. Please check your inbox.");
        return;
      }

      if (!mounted) return;
      setState(() {
        isLoading = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const DashboardPage(),
        ),
      );
    } catch (e) {
      debugPrint("Biometric login error: $e");
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      showMessage("Biometric login failed: $e");
    }
  }

  Future<void> _clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("saved_email");
    await prefs.remove("saved_password");
    setState(() {
      _hasSavedCredentials = false;
    });
    showMessage("Biometric login credentials cleared.");
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showMessage("Please enter email and password.");
      return;
    }

    if (!isValidEmail(email)) {
      showMessage("Invalid email format. Please enter a valid email address.");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user!.reload();

      final user = FirebaseAuth.instance.currentUser;

      if (user != null &&
          user.email != "admin@gmail.com" &&
          !user.emailVerified) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        showMessage("Email is not verified. Please check your email inbox.");
        return;
      }

      // Save credentials for Biometrics if enabled
      final prefs = await SharedPreferences.getInstance();
      if (_enableBiometricLogin) {
        await prefs.setString("saved_email", _encryptData(email));
        await prefs.setString("saved_password", _encryptData(password));
      } else {
        await prefs.remove("saved_email");
        await prefs.remove("saved_password");
      }

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const DashboardPage(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = "Invalid login. Please check your email and password.";

      if (e.code == "wrong-password") {
        message = "Incorrect password.";
      } else if (e.code == "invalid-email") {
        message = "Invalid email format.";
      } else if (e.code == "user-not-found") {
        message = "Email not registered.";
      } else if (e.code == "invalid-credential") {
        message = "Incorrect password.";
      } else if (e.code == "too-many-requests") {
        message = "Too many failed login attempts. Please try again later.";
      } else if (e.code == "user-disabled") {
        message = "This account has been disabled.";
      } else if (e.code == "network-request-failed") {
        message = "Network error. Please check your internet connection.";
      }

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage(message);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage("Login error: $e");
    }
  }

  Future<void> signInWithGoogle() async {
    setState(() {
      isLoading = true;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();

      try {
        await googleSignIn.signOut();
      } catch (e) {
        // Ignore sign out error.
      }

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;

      if (user != null) {
        final database = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: databaseURL,
        );

        final userRef = database.ref("Users").child(user.uid);
        final snapshot = await userRef.get();

        if (!snapshot.exists || snapshot.value == null) {
          await userRef.set({
            "username": user.displayName ?? user.email!.split('@')[0],
            "email": user.email,
            "role": "User",
            "createdAt": DateTime.now().toString(),
            "profileImagePath": "",
          });
        }

        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const DashboardPage(),
          ),
        );
      } else {
        throw Exception("Failed to retrieve user information from Google.");
      }
    } on FirebaseAuthException catch (e) {
      String message = "Google Sign-In failed.";

      if (e.code == "account-exists-with-different-credential") {
        message = "An account already exists with the same email address.";
      } else if (e.code == "invalid-credential") {
        message = "Error using Google credentials.";
      } else if (e.code == "network-request-failed") {
        message = "Network error. Please check your internet connection.";
      }

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage(message);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage("Google Sign-In error: $e");
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
    return isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final double logoSize =
        (MediaQuery.of(context).size.width * 0.26).clamp(85.0, 120.0).toDouble();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return IconButton(
                icon: Icon(
                  themeProvider.isDarkMode
                      ? Icons.light_mode
                      : Icons.dark_mode,
                  color: getMainTextColor(isDarkMode),
                ),
                onPressed: () {
                  themeProvider.toggleTheme(!themeProvider.isDarkMode);
                },
              );
            },
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF070B13),
                    const Color(0xFF1E152A),
                  ]
                : [
                    const Color(0xFFE0F2FE),
                    Colors.white,
                    const Color(0xFFF1F5F9),
                  ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF1E293B).withOpacity(0.85)
                      : Colors.white.withOpacity(0.9),
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: isDarkMode
                                ? const Color(0xFF06B6D4).withOpacity(0.18)
                                : const Color(0xFF0284C7).withOpacity(0.10),
                            blurRadius: 18,
                            spreadRadius: 0,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/images/flood_logo.png',
                          width: logoSize,
                          height: logoSize,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      "Welcome Back",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: getMainTextColor(isDarkMode),
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      "Smart Flood Early Warning Car System",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: getSubTextColor(isDarkMode),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 28),

                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(
                        color: getMainTextColor(isDarkMode),
                      ),
                      decoration: InputDecoration(
                        labelText: "Email",
                        labelStyle: TextStyle(
                          color: isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: isDarkMode
                              ? const Color(0xFF06B6D4)
                              : const Color(0xFF0284C7),
                        ),
                        filled: true,
                        fillColor: isDarkMode
                            ? const Color(0xFF0F172A).withOpacity(0.5)
                            : Colors.grey.shade100,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: isDarkMode
                                ? const Color(0xFF334155)
                                : const Color(0xFFCBD5E1),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: isDarkMode
                                ? const Color(0xFF06B6D4)
                                : const Color(0xFF0284C7),
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      style: TextStyle(
                        color: getMainTextColor(isDarkMode),
                      ),
                      decoration: InputDecoration(
                        labelText: "Password",
                        labelStyle: TextStyle(
                          color: isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        prefixIcon: Icon(
                          Icons.lock_outline_rounded,
                          color: isDarkMode
                              ? const Color(0xFF06B6D4)
                              : const Color(0xFF0284C7),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: isDarkMode
                            ? const Color(0xFF0F172A).withOpacity(0.5)
                            : Colors.grey.shade100,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: isDarkMode
                                ? const Color(0xFF334155)
                                : const Color(0xFFCBD5E1),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: isDarkMode
                                ? const Color(0xFF06B6D4)
                                : const Color(0xFF0284C7),
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    if (_canCheckBiometrics && _biometricsAvailable)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _enableBiometricLogin,
                                activeColor: isDarkMode
                                    ? const Color(0xFF06B6D4)
                                    : const Color(0xFF0284C7),
                                onChanged: (val) {
                                  setState(() {
                                    _enableBiometricLogin = val ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Enable Biometric Login next time",
                              style: TextStyle(
                                fontSize: 13,
                                color: getSubTextColor(isDarkMode),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDarkMode
                                    ? const Color(0xFF06B6D4)
                                    : const Color(0xFF0284C7),
                                foregroundColor:
                                    isDarkMode ? Colors.black : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: isLoading
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: isDarkMode
                                            ? Colors.black
                                            : Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      "Login",
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        if (_canCheckBiometrics && _biometricsAvailable && _hasSavedCredentials) ...[
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 54,
                            height: 54,
                            child: IconButton(
                              onPressed: isLoading ? null : loginWithBiometrics,
                              style: IconButton.styleFrom(
                                backgroundColor: isDarkMode
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                                foregroundColor: isDarkMode
                                    ? const Color(0xFF06B6D4)
                                    : const Color(0xFF0284C7),
                                side: BorderSide(
                                  color: isDarkMode
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFCBD5E1),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              icon: const Icon(
                                Icons.fingerprint_rounded,
                                size: 30,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: isDarkMode
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            "OR",
                            style: TextStyle(
                              color:
                                  getSubTextColor(isDarkMode).withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: isDarkMode
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: isLoading ? null : signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isDarkMode
                                ? const Color(0xFF334155)
                                : const Color(0xFFCBD5E1),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          backgroundColor: isDarkMode
                              ? const Color(0xFF0B0F19)
                              : Colors.white,
                          foregroundColor: getMainTextColor(isDarkMode),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(
                              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/480px-Google_%22G%22_logo.svg.png',
                              height: 22,
                              width: 22,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                Icons.g_mobiledata,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              "Sign in with Google",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignupPage(),
                                ),
                              );
                            },
                      child: Text(
                        "Don't have an account? Sign Up",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? const Color(0xFF06B6D4)
                              : const Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}