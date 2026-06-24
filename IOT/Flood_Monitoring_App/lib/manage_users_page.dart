import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class ManageUsersPage extends StatelessWidget {
  const ManageUsersPage({super.key});

  final String databaseURL =
      "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app";

  FirebaseDatabase get database {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: databaseURL,
    );
  }

  DatabaseReference get usersRef {
    return database.ref("Users");
  }

  DatabaseReference get auditRef {
    return database.ref("AuditLogs");
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

  Color getRoleColor(String role) {
    if (role.toLowerCase() == "admin") {
      return Colors.redAccent;
    }

    return Colors.lightBlue;
  }

  Future<void> writeAuditLog({
    required String action,
    required String details,
    required String severity,
  }) async {
    final adminUser = FirebaseAuth.instance.currentUser;

    await auditRef.push().set({
      "action": action,
      "details": details,
      "severity": severity,
      "source": adminUser?.email ?? "Unknown admin",
      "category": "ADMIN",
      "timestamp": DateTime.now().toString(),
      "createdAtEpoch": DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
  }

  Future<void> updateUserRole({
    required BuildContext context,
    required String uid,
    required String username,
    required String newRole,
  }) async {
    try {
      await usersRef.child(uid).update({
        "role": newRole,
        "updatedAt": DateTime.now().toString(),
      });

      await writeAuditLog(
        action: "User role updated",
        details: "$username role changed to $newRole",
        severity: "MEDIUM",
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$username is now $newRole"),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to update role: $e"),
        ),
      );
    }
  }

  Future<void> deleteUserRecord({
    required BuildContext context,
    required String uid,
    required String username,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser?.uid == uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You cannot delete your own admin record."),
        ),
      );
      return;
    }

    try {
      await usersRef.child(uid).remove();

      await writeAuditLog(
        action: "User database record deleted",
        details: "$username database record was deleted from Realtime Database",
        severity: "HIGH",
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("User record deleted"),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to delete user: $e"),
        ),
      );
    }
  }

  void showRoleDialog({
    required BuildContext context,
    required String uid,
    required String username,
    required String currentRole,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Change User Role"),
          content: Text("Select a new role for $username."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.person),
              label: const Text("User"),
              onPressed: () async {
                Navigator.pop(dialogContext);

                await updateUserRole(
                  context: context,
                  uid: uid,
                  username: username,
                  newRole: "User",
                );
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text("Admin"),
              onPressed: () async {
                Navigator.pop(dialogContext);

                await updateUserRole(
                  context: context,
                  uid: uid,
                  username: username,
                  newRole: "Admin",
                );
              },
            ),
          ],
        );
      },
    );
  }

  void showDeleteDialog({
    required BuildContext context,
    required String uid,
    required String username,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Delete User Record"),
          content: Text(
            "Delete $username from the database?\n\nThis will not delete the Firebase Authentication account.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);

                await deleteUserRecord(
                  context: context,
                  uid: uid,
                  username: username,
                );
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  Widget buildHeader(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [
                  const Color(0xFF1E3A8A),
                  const Color(0xFF0F172A),
                ]
              : [
                  Colors.lightBlue,
                  Colors.blueAccent,
                ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.30 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Manage Users",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "View users, update roles, and manage access records",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.white.withOpacity(0.88),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildUserCard({
    required BuildContext context,
    required String uid,
    required Map<dynamic, dynamic> user,
    required bool isDarkMode,
  }) {
    final username = user["username"]?.toString() ?? "No Name";
    final email = user["email"]?.toString() ?? "No Email";
    final role = user["role"]?.toString() ?? "User";
    final createdAt = user["createdAt"]?.toString() ?? "--";

    final roleColor = getRoleColor(role);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getCardColor(isDarkMode),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: roleColor.withOpacity(0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: roleColor.withOpacity(0.15),
                child: Icon(
                  role.toLowerCase() == "admin"
                      ? Icons.admin_panel_settings_rounded
                      : Icons.person_rounded,
                  color: roleColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: getMainTextColor(isDarkMode),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        color: getSubTextColor(isDarkMode),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: TextStyle(
                    color: roleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.badge_rounded,
                size: 18,
                color: getSubTextColor(isDarkMode),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "UID: $uid",
                  style: TextStyle(
                    fontSize: 12,
                    color: getSubTextColor(isDarkMode),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: getSubTextColor(isDarkMode),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Created: $createdAt",
                  style: TextStyle(
                    fontSize: 12,
                    color: getSubTextColor(isDarkMode),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text("Change Role"),
                  onPressed: () {
                    showRoleDialog(
                      context: context,
                      uid: uid,
                      username: username,
                      currentRole: role,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete_rounded),
                  label: const Text("Delete"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    showDeleteDialog(
                      context: context,
                      uid: uid,
                      username: username,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildEmptyState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_off_rounded,
              size: 80,
              color: getSubTextColor(isDarkMode),
            ),
            const SizedBox(height: 16),
            Text(
              "No users found",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: getMainTextColor(isDarkMode),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Registered users will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: getSubTextColor(isDarkMode),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: getBackgroundColor(isDarkMode),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: getBackgroundColor(isDarkMode),
        foregroundColor: getMainTextColor(isDarkMode),
        title: const Text("Manage Users"),
        centerTitle: true,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: usersRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "Error loading users: ${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final data = snapshot.data!.snapshot.value;

          if (data == null) {
            return buildEmptyState(isDarkMode);
          }

          final users = Map<dynamic, dynamic>.from(data as Map);
          final keys = users.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: keys.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  children: [
                    buildHeader(isDarkMode),
                    const SizedBox(height: 18),
                  ],
                );
              }

              final uid = keys[index - 1].toString();

              final user = Map<dynamic, dynamic>.from(
                users[keys[index - 1]],
              );

              return buildUserCard(
                context: context,
                uid: uid,
                user: user,
                isDarkMode: isDarkMode,
              );
            },
          );
        },
      ),
    );
  }
}