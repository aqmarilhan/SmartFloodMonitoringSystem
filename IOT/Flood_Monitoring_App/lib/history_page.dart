import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    checkAdminAccess();
  }

  Future<void> checkAdminAccess() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      setState(() {
        isAdmin = false;
      });
      return;
    }

    final database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app",
    );

    final snapshot = await database
        .ref("Users/${currentUser.uid}/role")
        .get()
        .timeout(const Duration(seconds: 10));

    if (snapshot.exists && snapshot.value != null) {
      final role = snapshot.value.toString().toLowerCase();

      setState(() {
        isAdmin = role == "admin";
      });

      debugPrint("History Page UID: ${currentUser.uid}");
      debugPrint("History Page Role: $role");
      debugPrint("History Page Is Admin: $isAdmin");
    } else {
      setState(() {
        isAdmin = false;
      });

      debugPrint("No role found for this user");
    }
  }

  Future<void> clearHistory() async {
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Only admin can delete history"),
        ),
      );
      return;
    }

    final FirebaseDatabase database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app",
    );

    await database.ref("History").remove();

    await database.ref("Statistics").set({
      "warningCount": 0,
      "dangerousCount": 0,
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("History cleared successfully"),
      ),
    );
  }

  Color getHistoryStatusColor(String status) {
    if (status == "WARNING") {
      return Colors.orange;
    } else if (status == "DANGEROUS") {
      return Colors.red;
    } else if (status == "SAFE") {
      return Colors.green;
    } else {
      return Colors.grey;
    }
  }

  IconData getHistoryStatusIcon(String status) {
    if (status == "DANGEROUS") {
      return Icons.dangerous_rounded;
    } else if (status == "WARNING") {
      return Icons.warning_amber_rounded;
    } else if (status == "SAFE") {
      return Icons.check_circle_rounded;
    } else {
      return Icons.history;
    }
  }

  Widget historyInfoItem({
    required IconData icon,
    required String title,
    required String value,
    required bool isDarkMode,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: isDarkMode ? Colors.lightBlueAccent : Colors.blue,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int getTimestampValue(Map<dynamic, dynamic> history) {
    final timestamp = history["timestamp"];

    if (timestamp == null) return 0;

    if (timestamp is int) {
      return timestamp;
    }

    if (timestamp is double) {
      return timestamp.toInt();
    }

    if (timestamp is String) {
      final intTime = int.tryParse(timestamp);
      if (intTime != null) return intTime;

      final dateTime = DateTime.tryParse(timestamp);
      if (dateTime != null) {
        return dateTime.millisecondsSinceEpoch;
      }
    }

    return 0;
  }

  String formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "--";

    if (timestamp is int) {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return dateTime.toString().substring(0, 19);
    }

    if (timestamp is double) {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
      return dateTime.toString().substring(0, 19);
    }

    return timestamp.toString();
  }

  String formatDistance(dynamic distance) {
    if (distance == null) return "--";

    final value = double.tryParse(distance.toString());

    if (value == null) return "--";

    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final FirebaseDatabase database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app",
    );

    final DatabaseReference historyRef = database.ref("History");

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF0F172A) : Colors.lightBlue.shade50,
      appBar: AppBar(
        title: const Text("Flood History"),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Clear History"),
                    content: const Text(
                      "Delete all flood history records?",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          clearHistory();
                        },
                        child: const Text("Delete"),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: StreamBuilder<DatabaseEvent>(
      stream: historyRef.limitToLast(100).onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                "Error loading history: ${snapshot.error}",
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
            return Center(
              child: Text(
                "No History Found",
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode
                      ? Colors.grey.shade300
                      : Colors.grey.shade700,
                ),
              ),
            );
          }

          final historyMap = Map<dynamic, dynamic>.from(data as Map);

          final historyList = historyMap.entries.map((entry) {
            final history = Map<dynamic, dynamic>.from(entry.value);
            history["id"] = entry.key;
            return history;
          }).toList();

          historyList.sort((a, b) {
            final timeA = getTimestampValue(a);
            final timeB = getTimestampValue(b);

            return timeB.compareTo(timeA);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: historyList.length,
            itemBuilder: (context, index) {
              final history = historyList[index];

              final status = history["flood_status"]?.toString() ?? "--";
              final statusColor = getHistoryStatusColor(status);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1F2937) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDarkMode ? 0.25 : 0.08,
                      ),
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
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            getHistoryStatusIcon(status),
                            color: statusColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                status,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatTimestamp(history["timestamp"]),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDarkMode
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(
                      color: isDarkMode
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: historyInfoItem(
                            icon: Icons.straighten,
                            title: "Distance",
                            value:
                                "${formatDistance(history["distance_cm"])} cm",
                            isDarkMode: isDarkMode,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: historyInfoItem(
                            icon: Icons.water_drop,
                            title: "Water Level",
                            value: history["water_level"]?.toString() ?? "--",
                            isDarkMode: isDarkMode,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    historyInfoItem(
                      icon: Icons.lightbulb,
                      title: "LED Indicator",
                      value:
                          history["led_indicator_status"]?.toString() ?? "--",
                      isDarkMode: isDarkMode,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}