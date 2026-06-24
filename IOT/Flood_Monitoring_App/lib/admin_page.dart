import 'package:flutter/material.dart';
import 'manage_users_page.dart';
import 'admin_threshold_page.dart';
import 'device_health_page.dart';
import 'audit_log_page.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

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

  Widget buildHeader(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [
                  const Color(0xFF7F1D1D),
                  const Color(0xFF0F172A),
                ]
              : [
                  Colors.redAccent,
                  Colors.deepOrange,
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
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Admin Panel",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Manage users, calibration, device health, and audit records",
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

  Widget buildAdminCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Widget page,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: getCardColor(isDarkMode),
        borderRadius: BorderRadius.circular(24),
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
          vertical: 14,
        ),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: color.withOpacity(0.15),
          child: Icon(
            icon,
            color: color,
            size: 30,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: getMainTextColor(isDarkMode),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: getSubTextColor(isDarkMode),
            ),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 18,
          color: getSubTextColor(isDarkMode),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => page,
            ),
          );
        },
      ),
    );
  }

  Widget buildWarningBox(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.orange.withOpacity(0.12)
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.orange.withOpacity(0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Admin features should only be used by authorized users. Changes may affect flood detection, user access, and system records.",
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: getMainTextColor(isDarkMode),
              ),
            ),
          ),
        ],
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
        title: const Text("Admin Panel"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          buildHeader(isDarkMode),

          const SizedBox(height: 18),

          buildWarningBox(isDarkMode),

          const SizedBox(height: 18),

          buildAdminCard(
            context: context,
            icon: Icons.people_alt_rounded,
            title: "Manage Users",
            subtitle: "Manage user roles and access permissions",
            color: Colors.blue,
            page: const ManageUsersPage(),
            isDarkMode: isDarkMode,
          ),

          buildAdminCard(
            context: context,
            icon: Icons.tune_rounded,
            title: "Threshold Calibration",
            subtitle: "Adjust sensor reference height and flood alert levels",
            color: Colors.deepPurple,
            page: const AdminThresholdPage(),
            isDarkMode: isDarkMode,
          ),

          buildAdminCard(
            context: context,
            icon: Icons.memory_rounded,
            title: "Device Health",
            subtitle: "Monitor ESP32, WiFi, and sensor condition",
            color: Colors.green,
            page: const DeviceHealthPage(),
            isDarkMode: isDarkMode,
          ),

          buildAdminCard(
            context: context,
            icon: Icons.security_rounded,
            title: "Audit Logs",
            subtitle: "View admin and system activity records",
            color: Colors.redAccent,
            page: const AuditLogPage(),
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }
}