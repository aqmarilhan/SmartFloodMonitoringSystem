import 'package:crypto/crypto.dart';
import 'dart:convert';
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
  bool isSelectionMode = false;
  final Set<String> selectedIds = {};
  List<String> _currentVisibleIds = [];

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

  Future<void> deleteSelectedHistory() async {
    if (!isAdmin || selectedIds.isEmpty) return;

    final FirebaseDatabase database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app",
    );

    final historyRef = database.ref("History");

    final Map<String, dynamic> updates = {};
    for (final id in selectedIds) {
      updates[id] = null;
    }

    try {
      await historyRef.update(updates);
      
      setState(() {
        selectedIds.clear();
        isSelectionMode = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Selected history records deleted successfully"),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting records: $e"),
        ),
      );
    }
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
          size: 16,
          color: isDarkMode ? Colors.lightBlueAccent : Colors.blue,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
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

  int verifyDataIntegrity(Map<dynamic, dynamic> history) {
    final hashVal = history["hash"]?.toString();
    if (hashVal == null || hashVal.isEmpty) {
      return 0; // Unsigned (legacy)
    }

    final distanceStr = formatDistance(history["distance_cm"]);
    final waterLevelStr = history["water_level"]?.toString() ?? "--";
    final statusStr = history["flood_status"]?.toString() ?? "--";
    final ledStr = history["led_indicator_status"]?.toString() ?? "--";
    final timestampStr = history["timestamp"]?.toString() ?? "--";

    final dataToHash = "$distanceStr$waterLevelStr$statusStr$ledStr$timestampStr";
    final computedHash = sha256.convert(utf8.encode(dataToHash + "FloodSecuritySalt123!")).toString();

    if (computedHash == hashVal) {
      return 1; // Verified
    } else {
      return -1; // Tamper detected!
    }
  }

  Widget buildIntegrityBadge(Map<dynamic, dynamic> history, bool isDarkMode) {
    final verification = verifyDataIntegrity(history);

    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    if (verification == 1) {
      bgColor = Colors.green.withValues(alpha: 0.16);
      textColor = isDarkMode ? Colors.greenAccent : Colors.green.shade700;
      icon = Icons.verified_user_rounded;
      label = "Verified";
    } else if (verification == -1) {
      bgColor = Colors.red.withValues(alpha: 0.16);
      textColor = isDarkMode ? Colors.redAccent : Colors.red.shade700;
      icon = Icons.gpp_bad_rounded;
      label = "Tampered!";
    } else {
      bgColor = Colors.grey.withValues(alpha: 0.16);
      textColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700;
      icon = Icons.help_outline_rounded;
      label = "Legacy";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: textColor,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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
        title: Text(isSelectionMode ? "${selectedIds.length} Selected" : "Flood History"),
        leading: isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    isSelectionMode = false;
                    selectedIds.clear();
                  });
                },
              )
            : null,
        actions: [
          if (isAdmin) ...[
            if (isSelectionMode) ...[
              IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: "Select All",
                onPressed: () {
                  setState(() {
                    if (selectedIds.length == _currentVisibleIds.length) {
                      selectedIds.clear();
                    } else {
                      selectedIds.addAll(_currentVisibleIds);
                    }
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: "Delete Selected",
                onPressed: () {
                  if (selectedIds.isEmpty) return;
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Delete Selected"),
                      content: Text(
                        "Delete ${selectedIds.length} selected history records?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            deleteSelectedHistory();
                          },
                          child: const Text("Delete"),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ] else ...[
              IconButton(
                icon: const Icon(Icons.playlist_add_check),
                tooltip: "Select Mode",
                onPressed: () {
                  setState(() {
                    isSelectionMode = true;
                    selectedIds.clear();
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_forever),
                tooltip: "Clear All",
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
                          onPressed: () => Navigator.pop(context),
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
            ]
          ]
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: StreamBuilder<DatabaseEvent>(
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

          // Track visible IDs for Select All feature
          _currentVisibleIds = historyList.map((h) => h["id"].toString()).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: historyList.length,
            itemBuilder: (context, index) {
              final history = historyList[index];
              final id = history["id"].toString();

              final status = history["flood_status"]?.toString() ?? "--";
              final statusColor = getHistoryStatusColor(status);
              final isSelected = selectedIds.contains(id);

              return Row(
                children: [
                  if (isSelectionMode && isAdmin)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Checkbox(
                        value: isSelected,
                        activeColor: isDarkMode
                            ? const Color(0xFF06B6D4)
                            : const Color(0xFF0284C7),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              selectedIds.add(id);
                            } else {
                              selectedIds.remove(id);
                            }
                          });
                        },
                      ),
                    ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        if (isSelectionMode && isAdmin) {
                          setState(() {
                            if (isSelected) {
                              selectedIds.remove(id);
                            } else {
                              selectedIds.add(id);
                            }
                          });
                        }
                      },
                      onLongPress: () {
                        if (!isSelectionMode && isAdmin) {
                          setState(() {
                            isSelectionMode = true;
                            selectedIds.add(id);
                          });
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? (isDarkMode ? const Color(0xFF06B6D4) : const Color(0xFF0284C7))
                                : statusColor.withValues(alpha: 0.20),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDarkMode ? 0.20 : 0.06,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    getHistoryStatusIcon(status),
                                    color: statusColor,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        formatTimestamp(history["timestamp"]),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDarkMode
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                buildIntegrityBadge(history, isDarkMode),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Divider(
                              height: 1,
                              color: isDarkMode
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                            ),
                            const SizedBox(height: 8),
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
                                const SizedBox(width: 10),
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
                            const SizedBox(height: 8),
                            historyInfoItem(
                              icon: Icons.lightbulb,
                              title: "LED Indicator",
                              value:
                                  history["led_indicator_status"]?.toString() ?? "--",
                              isDarkMode: isDarkMode,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
          ),
    );
  }
}