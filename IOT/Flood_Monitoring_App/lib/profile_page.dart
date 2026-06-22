import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'login_page.dart';
import 'theme_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String username = "Loading...";
  String role = "Loading...";
  String createdAt = "Loading...";
  String email = "Not Available";
  String emailVerification = "Not Verified";
  String profileImagePath = "";

  bool isLoading = true;
  bool isUploadingImage = false;

  User? get user => FirebaseAuth.instance.currentUser;

  DatabaseReference get userRef {
    final currentUser = FirebaseAuth.instance.currentUser;

    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app",
    ).ref("Users/${currentUser!.uid}");
  }

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  String formatDate(String value) {
    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    return date.toString().substring(0, 19);
  }

  Future<void> loadUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      setState(() {
        username = "Guest User";
        role = "Unknown";
        createdAt = "Not Available";
        email = "Not Available";
        emailVerification = "Not Verified";
        isLoading = false;
      });
      return;
    }

    email = currentUser.email ?? "Not Available";
    emailVerification =
        currentUser.emailVerified ? "Verified" : "Not Verified";

    try {
      final snapshot = await userRef.get().timeout(const Duration(seconds: 10));

      if (snapshot.exists && snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);

        setState(() {
          username =
              data["username"]?.toString() ??
              currentUser.displayName ??
              "User";

          role = data["role"]?.toString() ?? "User";

          createdAt = formatDate(
            data["createdAt"]?.toString() ??
                currentUser.metadata.creationTime?.toString() ??
                "Unknown",
          );

          profileImagePath =
              data["profileImagePath"]?.toString() ?? "";

          isLoading = false;
        });
      } else {
        await userRef.set({
          "username": currentUser.displayName ?? "User",
          "email": email,
          "role": "User",
          "createdAt": DateTime.now().toString(),
          "profileImagePath": "",
        });

        setState(() {
          username = currentUser.displayName ?? "User";
          role = "User";
          createdAt = DateTime.now().toString().substring(0, 19);
          profileImagePath = "";
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Profile Load Error: $e");

      setState(() {
        username = currentUser.displayName ?? "User";
        role = "User";
        createdAt =
            currentUser.metadata.creationTime?.toString().substring(0, 19) ??
                "Unknown";
        isLoading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to load profile: $e"),
        ),
      );
    }
  }

  Future<void> pickAndUploadImage() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    final picker = ImagePicker();

    final XFile? pickedImage = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 800,
    );

    if (pickedImage == null) {
      return;
    }

    setState(() {
      isUploadingImage = true;
    });

    try {
      await userRef.update({
        "profileImagePath": pickedImage.path,
        "updatedAt": DateTime.now().toString(),
      });

      if (!mounted) return;

      setState(() {
        profileImagePath = pickedImage.path;
        isUploadingImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile photo updated successfully"),
        ),
      );
    } catch (e) {
      debugPrint("Image Save Error: $e");

      if (!mounted) return;

      setState(() {
        isUploadingImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to update image: $e"),
        ),
      );
    }
  }

  Future<void> editUsername() async {
    final controller = TextEditingController(text: username);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Edit Username"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: "Username",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final newUsername = controller.text.trim();

                if (newUsername.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Username cannot be empty"),
                    ),
                  );
                  return;
                }

                try {
                  await userRef.update({
                    "username": newUsername,
                    "updatedAt": DateTime.now().toString(),
                  });

                  await FirebaseAuth.instance.currentUser
                      ?.updateDisplayName(newUsername);

                  setState(() {
                    username = newUsername;
                  });

                  if (!dialogContext.mounted) return;

                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Username updated successfully"),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error: $e"),
                    ),
                  );
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
      (route) => false,
    );
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

  Color getRoleColor() {
    if (role.toLowerCase() == "admin") {
      return Colors.redAccent;
    }

    return Colors.lightBlue;
  }

  Widget buildProfileImage() {
    final bool hasLocalImage =
        profileImagePath.isNotEmpty && File(profileImagePath).existsSync();

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 58,
          backgroundColor: Colors.white.withOpacity(0.25),
          backgroundImage: hasLocalImage
              ? FileImage(File(profileImagePath))
              : null,
          child: !hasLocalImage
              ? const Icon(
                  Icons.person,
                  size: 70,
                  color: Colors.white,
                )
              : null,
        ),
        GestureDetector(
          onTap: isUploadingImage ? null : pickAndUploadImage,
          child: CircleAvatar(
            radius: 21,
            backgroundColor: Colors.white,
            child: isUploadingImage
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.camera_alt,
                    color: Colors.blue,
                    size: 22,
                  ),
          ),
        ),
      ],
    );
  }

  Widget buildHeader(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [
                  const Color(0xFF0F172A),
                  const Color(0xFF1E293B),
                ]
              : [
                  Colors.lightBlue,
                  Colors.blueAccent,
                ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Column(
        children: [
          buildProfileImage(),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  username,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                onPressed: editUsername,
                icon: const Icon(
                  Icons.edit,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: getRoleColor(),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              role.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required bool isDarkMode,
    Color? iconColor,
  }) {
    final color = iconColor ?? Colors.lightBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: getCardColor(isDarkMode),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: getSubTextColor(isDarkMode),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: getMainTextColor(isDarkMode),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildDarkModeCard(bool isDarkMode) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: getCardColor(isDarkMode),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 8,
            ),
            secondary: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.15),
              child: Icon(
                themeProvider.isDarkMode
                    ? Icons.dark_mode
                    : Icons.light_mode,
                color: Colors.orange,
              ),
            ),
            title: Text(
              "Dark Mode",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: getMainTextColor(isDarkMode),
              ),
            ),
            subtitle: Text(
              themeProvider.isDarkMode
                  ? "Dark theme is enabled"
                  : "Light theme is enabled",
              style: TextStyle(
                color: getSubTextColor(isDarkMode),
              ),
            ),
            value: themeProvider.isDarkMode,
            onChanged: (value) {
              themeProvider.toggleTheme(value);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: getBackgroundColor(isDarkMode),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: buildHeader(isDarkMode),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      buildInfoCard(
                        icon: Icons.person,
                        title: "Username",
                        value: username,
                        isDarkMode: isDarkMode,
                      ),
                      buildInfoCard(
                        icon: Icons.email,
                        title: "Email",
                        value: email,
                        isDarkMode: isDarkMode,
                      ),
                      buildInfoCard(
                        icon: emailVerification == "Verified"
                            ? Icons.verified_user
                            : Icons.gpp_maybe,
                        title: "Email Verification",
                        value: emailVerification,
                        isDarkMode: isDarkMode,
                        iconColor: emailVerification == "Verified"
                            ? Colors.green
                            : Colors.orange,
                      ),
                      buildInfoCard(
                        icon: Icons.badge,
                        title: "Role",
                        value: role,
                        isDarkMode: isDarkMode,
                        iconColor: getRoleColor(),
                      ),
                      buildInfoCard(
                        icon: Icons.calendar_month,
                        title: "Account Created",
                        value: createdAt,
                        isDarkMode: isDarkMode,
                      ),
                      buildDarkModeCard(isDarkMode),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.logout),
                        label: const Text("Logout"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 54),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: logout,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}