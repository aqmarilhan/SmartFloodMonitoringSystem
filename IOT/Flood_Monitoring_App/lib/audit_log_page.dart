import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class AuditLogPage extends StatelessWidget {
  const AuditLogPage({super.key});

  final String databaseURL =
      "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app/";

  DatabaseReference get auditRef => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: databaseURL,
      ).ref("AuditLogs");

  int getEpoch(Map<String, dynamic> log) {
    final value = log["createdAtEpoch"];

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? "") ?? 0;
  }

  String getText(Map<String, dynamic> log, String key) {
    return log[key]?.toString() ?? "--";
  }

  String formatEpoch(int epoch) {
    if (epoch == 0) {
      return "--";
    }

    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      epoch * 1000,
    );

    return dateTime.toString().substring(0, 19);
  }

  Color getSeverityColor(String severity) {
    final value = severity.toUpperCase();

    if (value == "HIGH") {
      return Colors.redAccent;
    }

    if (value == "MEDIUM") {
      return Colors.orange;
    }

    if (value == "LOW") {
      return Colors.green;
    }

    return Colors.grey;
  }

  IconData getSeverityIcon(String severity) {
    final value = severity.toUpperCase();

    if (value == "HIGH") {
      return Icons.dangerous_rounded;
    }

    if (value == "MEDIUM") {
      return Icons.warning_amber_rounded;
    }

    if (value == "LOW") {
      return Icons.info_rounded;
    }

    return Icons.history_rounded;
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

  Widget buildHeader(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.security_rounded,
              color: Colors.white,
              size: 70,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Audit Logs",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Track admin actions, threshold updates, and system activities",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: Colors.white.withOpacity(0.88),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required bool isDarkMode,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: isDarkMode ? Colors.lightBlueAccent : Colors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "$title: ",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: getSubTextColor(isDarkMode),
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 13,
                      color: getMainTextColor(isDarkMode),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLogCard({
    required Map<String, dynamic> log,
    required bool isDarkMode,
  }) {
    final action = getText(log, "action");
    final details = getText(log, "details");
    final severity = getText(log, "severity");
    final source = getText(log, "source");
    final category = getText(log, "category");
    final epoch = getEpoch(log);

    final color = getSeverityColor(severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getCardColor(isDarkMode),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withOpacity(0.25),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(
                  getSeverityIcon(severity),
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  action,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: getMainTextColor(isDarkMode),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  severity.toUpperCase(),
                  style: TextStyle(
                    color: color,
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
          buildInfoRow(
            icon: Icons.description_rounded,
            title: "Details",
            value: details,
            isDarkMode: isDarkMode,
          ),
          buildInfoRow(
            icon: Icons.person_rounded,
            title: "Source",
            value: source,
            isDarkMode: isDarkMode,
          ),
          buildInfoRow(
            icon: Icons.category_rounded,
            title: "Category",
            value: category,
            isDarkMode: isDarkMode,
          ),
          buildInfoRow(
            icon: Icons.access_time_rounded,
            title: "Time",
            value: formatEpoch(epoch),
            isDarkMode: isDarkMode,
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
              Icons.history_toggle_off_rounded,
              size: 80,
              color: getSubTextColor(isDarkMode),
            ),
            const SizedBox(height: 16),
            Text(
              "No audit logs found",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: getMainTextColor(isDarkMode),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Admin and system activities will appear here.",
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
        title: const Text("Audit Logs"),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: StreamBuilder<DatabaseEvent>(
        stream: auditRef
            .orderByChild("createdAtEpoch")
            .limitToLast(50)
            .onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "Error loading logs: ${snapshot.error}",
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

          if (snapshot.data!.snapshot.value == null) {
            return buildEmptyState(isDarkMode);
          }

          final rawData = Map<dynamic, dynamic>.from(
            snapshot.data!.snapshot.value as Map,
          );

          final logs = <Map<String, dynamic>>[];

          rawData.forEach((key, value) {
            if (value is Map) {
              final log = Map<String, dynamic>.from(value);
              log["id"] = key.toString();
              logs.add(log);
            }
          });

          logs.sort((a, b) {
            return getEpoch(b).compareTo(getEpoch(a));
          });

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            itemCount: logs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  children: [
                    buildHeader(isDarkMode),
                    const SizedBox(height: 18),
                  ],
                );
              }

              final log = logs[index - 1];

              return buildLogCard(
                log: log,
                isDarkMode: isDarkMode,
              );
            },
          );
        },
      ),
          ),
    );
  }
}