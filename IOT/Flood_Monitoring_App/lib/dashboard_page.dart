import 'admin_page.dart';
import 'monitoring_page.dart';
import 'history_page.dart';
import 'login_page.dart';
import 'trend_page.dart';
import 'profile_page.dart';
import 'rating_page.dart';
import 'vehicle_location_page.dart';
import 'emergency_contact_page.dart';
import 'flood_risk_map_page.dart';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  double averageRating = 0.0;
  int totalRatings = 0;
  int warningCount = 0;
  int dangerousCount = 0;
  bool isAdmin = false;
  String currentFloodStatus = "SAFE";

  String lastSync = DateTime.now().toString().substring(0, 19);

  final String databaseURL =
      "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app";

  FirebaseDatabase get database {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: databaseURL,
    );
  }

  @override
  void initState() {
    super.initState();
    checkAdminAccess();
    listenToHistory();
    listenToRatings();
    listenToFloodStatus();
  }

  void listenToFloodStatus() {
    database.ref("FloodMonitoring").onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        final floodMap = Map<dynamic, dynamic>.from(data);
        final status = floodMap["flood_status"]?.toString() ?? "SAFE";
        if (!mounted) return;
        setState(() {
          currentFloodStatus = status;
        });
      }
    });
  }

  Future<void> checkAdminAccess() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (!mounted) return;

      setState(() {
        isAdmin = false;
      });
      return;
    }

    try {
      final snapshot = await database
          .ref("Users/${currentUser.uid}/role")
          .get()
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (snapshot.exists && snapshot.value != null) {
        final role = snapshot.value.toString().toLowerCase();

        setState(() {
          isAdmin = role == "admin";
        });

        debugPrint("Dashboard UID: ${currentUser.uid}");
        debugPrint("Dashboard Role: $role");
        debugPrint("Dashboard Is Admin: $isAdmin");
      } else {
        setState(() {
          isAdmin = false;
        });

        debugPrint("No role found for UID: ${currentUser.uid}");
      }
    } catch (e) {
      debugPrint("Error checking admin access: $e");
      if (!mounted) return;
      setState(() {
        isAdmin = false;
      });
    }
  }

  void listenToHistory() {
    database.ref("Statistics").onValue.listen((event) {
      int warnings = 0;
      int dangerous = 0;

      final data = event.snapshot.value;

      if (data != null && data is Map) {
        final statsMap = Map<dynamic, dynamic>.from(data);
        warnings = int.tryParse(statsMap["warningCount"]?.toString() ?? "0") ?? 0;
        dangerous = int.tryParse(statsMap["dangerousCount"]?.toString() ?? "0") ?? 0;
      }

      if (!mounted) return;

      setState(() {
        warningCount = warnings;
        dangerousCount = dangerous;
        lastSync = DateTime.now().toString().substring(0, 19);
      });
    });
  }

  void listenToRatings() {
    database.ref("Ratings").onValue.listen((event) {
      final data = event.snapshot.value;

      double total = 0;
      int count = 0;

      if (data != null && data is Map) {
        final ratingData = Map<dynamic, dynamic>.from(data);

        ratingData.forEach((key, value) {
          final item = Map<dynamic, dynamic>.from(value);

          total += (item["rating"] ?? 0).toDouble();
          count++;
        });
      }

      if (!mounted) return;

      setState(() {
        totalRatings = count;
        averageRating = count > 0 ? total / count : 0.0;
      });
    });
  }

  Future<void> refreshData() async {
    await checkAdminAccess();

    if (!mounted) return;

    setState(() {
      lastSync = DateTime.now().toString().substring(0, 19);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Dashboard refreshed"),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Logout"),
          content: const Text("Are you sure you want to logout?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text("Logout"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      // Ignore
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
      (route) => false,
    );
  }

  Color backgroundColor(bool isDarkMode) {
    return isDarkMode ? const Color(0xFF0F172A) : Colors.lightBlue.shade50;
  }

  Color cardColor(bool isDarkMode) {
    return isDarkMode ? const Color(0xFF1E293B) : Colors.white;
  }

  Color mainTextColor(bool isDarkMode) {
    return isDarkMode ? Colors.white : Colors.black87;
  }

  Color subTextColor(bool isDarkMode) {
    return isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700;
  }

  Widget buildHeroCard(bool isDarkMode) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    
    if (currentFloodStatus == "DANGEROUS") {
      statusColor = Colors.redAccent;
      statusLabel = "DANGER DETECTED";
      statusIcon = Icons.report_problem_rounded;
    } else if (currentFloodStatus == "WARNING") {
      statusColor = Colors.orangeAccent;
      statusLabel = "WARNING ACTIVE";
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = isDarkMode ? const Color(0xFF06B6D4) : const Color(0xFF0284C7);
      statusLabel = "SYSTEM SECURED";
      statusIcon = Icons.shield_outlined;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF1E293B).withOpacity(0.8)
            : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDarkMode
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? const Color(0xFF06B6D4).withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: statusColor.withOpacity(0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.2),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: isDarkMode ? const Color(0xFF0B0F19) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(
                  'assets/images/flood_logo_icon.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Smart Flood Monitoring",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              color: mainTextColor(isDarkMode),
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "IoT-Based Flood Early Warning Car System",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: subTextColor(isDarkMode),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: statusColor.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDarkMode ? const Color(0xFF8B5CF6) : const Color(0xFF4F46E5)).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: (isDarkMode ? const Color(0xFF8B5CF6) : const Color(0xFF4F46E5)).withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  isAdmin ? "ADMIN" : "USER",
                  style: TextStyle(
                    color: isDarkMode ? const Color(0xFFC084FC) : const Color(0xFF4F46E5),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isDarkMode,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF1E293B).withOpacity(0.7)
              : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDarkMode
                ? const Color(0xFF334155).withOpacity(0.6)
                : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: mainTextColor(isDarkMode),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                color: subTextColor(isDarkMode),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDashboardCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF1E293B).withOpacity(0.7)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode
              ? const Color(0xFF334155).withOpacity(0.6)
              : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: mainTextColor(isDarkMode),
            letterSpacing: -0.2,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(
              color: subTextColor(isDarkMode),
              fontSize: 13,
            ),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          color: subTextColor(isDarkMode).withOpacity(0.7),
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget buildSystemInfo(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor(isDarkMode),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "System Information",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: mainTextColor(isDarkMode),
            ),
          ),
          const SizedBox(height: 14),
          buildInfoRow(
            icon: Icons.cloud_done,
            text: "Firebase Connected",
            color: Colors.green,
            isDarkMode: isDarkMode,
          ),
          buildInfoRow(
            icon: Icons.notifications_active,
            text: "Notifications Enabled",
            color: Colors.orange,
            isDarkMode: isDarkMode,
          ),
          buildInfoRow(
            icon: Icons.sync,
            text: "Last Sync: $lastSync",
            color: Colors.blue,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget buildInfoRow({
    required IconData icon,
    required String text,
    required Color color,
    required bool isDarkMode,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: mainTextColor(isDarkMode),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRatingCard(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor(isDarkMode),
        borderRadius: BorderRadius.circular(24),
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
          Text(
            "App Rating",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: mainTextColor(isDarkMode),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              averageRating.round(),
              (index) => const Icon(
                Icons.star,
                color: Colors.amber,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            averageRating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: mainTextColor(isDarkMode),
            ),
          ),
          Text(
            "$totalRatings Reviews",
            style: TextStyle(
              color: subTextColor(isDarkMode),
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        SystemNavigator.pop();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: mainTextColor(isDarkMode),
          title: const Text(
            "Dashboard",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline_rounded),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfilePage(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: logout,
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
            child: RefreshIndicator(
              onRefresh: refreshData,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  buildHeroCard(isDarkMode),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      buildStatCard(
                        icon: Icons.warning_amber_rounded,
                        title: "Warnings",
                        value: "$warningCount",
                        color: Colors.orange,
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(width: 14),
                      buildStatCard(
                        icon: Icons.dangerous_rounded,
                        title: "Dangerous",
                        value: "$dangerousCount",
                        color: Colors.red,
                        isDarkMode: isDarkMode,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (isAdmin)
                    buildDashboardCard(
                      icon: Icons.admin_panel_settings_outlined,
                      title: "Admin Panel",
                      subtitle: "Manage users, thresholds and system logs",
                      color: Colors.redAccent,
                      isDarkMode: isDarkMode,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminPage(),
                          ),
                        );
                      },
                    ),

                  buildDashboardCard(
                    icon: Icons.water_drop_outlined,
                    title: "Monitoring",
                    subtitle: "View live flood sensor readings",
                    color: Colors.lightBlue,
                    isDarkMode: isDarkMode,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FloodMonitoringPage(),
                        ),
                      );
                    },
                  ),

                  buildDashboardCard(
                    icon: Icons.history_rounded,
                    title: "History",
                    subtitle: "View recorded flood events",
                    color: Colors.deepPurple,
                    isDarkMode: isDarkMode,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HistoryPage(),
                        ),
                      );

                      refreshData();
                    },
                  ),

                  buildDashboardCard(
                    icon: Icons.directions_car_rounded,
                    title: "Vehicle Management",
                    subtitle: "Register vehicles and control GPS coordinates",
                    color: Colors.indigo,
                    isDarkMode: isDarkMode,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VehicleLocationPage(),
                        ),
                      );
                    },
                  ),

                  buildDashboardCard(
                    icon: Icons.explore_outlined,
                    title: "Flood Risk Map",
                    subtitle: "Monitor active river sensor locations on a map",
                    color: Colors.blueAccent,
                    isDarkMode: isDarkMode,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FloodRiskMapPage(),
                        ),
                      );
                    },
                  ),

                  buildDashboardCard(
                    icon: Icons.show_chart_rounded,
                    title: "Trend Analysis",
                    subtitle: "Analyze flood risk over time",
                    color: Colors.teal,
                    isDarkMode: isDarkMode,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TrendPage(),
                        ),
                      );
                    },
                  ),

                  buildDashboardCard(
                    icon: Icons.contact_emergency_outlined,
                    title: "Emergency Contact",
                    subtitle: "Register and call emergency contact",
                    color: Colors.redAccent,
                    isDarkMode: isDarkMode,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EmergencyContactPage(),
                        ),
                      );
                    },
                  ),

                  buildDashboardCard(
                    icon: Icons.star_outline_rounded,
                    title: "Ratings",
                    subtitle: "Review user feedback",
                    color: Colors.amber,
                    isDarkMode: isDarkMode,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RatingPage(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 6),

                  buildSystemInfo(isDarkMode),

                  const SizedBox(height: 16),

                  buildRatingCard(isDarkMode),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}