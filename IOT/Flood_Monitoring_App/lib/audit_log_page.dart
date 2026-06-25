import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  bool isAdmin = false;
  bool isSelectionMode = false;
  final Set<String> selectedIds = {};
  List<String> _currentVisibleIds = [];

  final String databaseURL =
      "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app/";

  DatabaseReference get auditRef => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: databaseURL,
      ).ref("AuditLogs");

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
      databaseURL: databaseURL,
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
    } else {
      setState(() {
        isAdmin = false;
      });
    }
  }

  Future<void> clearAllLogs() async {
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Only admin can clear logs"),
        ),
      );
      return;
    }

    try {
      await auditRef.remove();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All audit logs cleared successfully"),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error clearing logs: $e"),
        ),
      );
    }
  }

  Future<void> deleteSelectedLogs() async {
    if (!isAdmin || selectedIds.isEmpty) return;

    final Map<String, dynamic> updates = {};
    for (final id in selectedIds) {
      updates[id] = null;
    }

    try {
      await auditRef.update(updates);
      
      setState(() {
        selectedIds.clear();
        isSelectionMode = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Selected audit logs deleted successfully"),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting logs: $e"),
        ),
      );
    }
  }

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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.30 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.security_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Audit Logs",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Track admin actions, threshold updates, and system activities",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
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
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDarkMode ? Colors.lightBlueAccent : Colors.blue,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "$title: ",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: getSubTextColor(isDarkMode),
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 12,
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
    required bool isSelected,
  }) {
    final action = getText(log, "action");
    final details = getText(log, "details");
    final severity = getText(log, "severity");
    final source = getText(log, "source");
    final category = getText(log, "category");
    final epoch = getEpoch(log);

    final color = getSeverityColor(severity);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: getCardColor(isDarkMode),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? (isDarkMode ? const Color(0xFF06B6D4) : const Color(0xFF0284C7))
              : color.withOpacity(0.20),
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.20 : 0.06),
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
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(
                  getSeverityIcon(severity),
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: getMainTextColor(isDarkMode),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  severity.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          const SizedBox(height: 4),
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
        title: Text(isSelectionMode ? "${selectedIds.length} Selected" : "Audit Logs"),
        centerTitle: true,
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
                      title: const Text("Delete Selected Logs"),
                      content: Text(
                        "Delete ${selectedIds.length} selected audit logs?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            deleteSelectedLogs();
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
                tooltip: "Clear All Logs",
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Clear Audit Logs"),
                      content: const Text(
                        "Delete all audit logs?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            clearAllLogs();
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

          // Track visible IDs for Select All feature
          _currentVisibleIds = logs.map((l) => l["id"].toString()).toList();

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: logs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  children: [
                    buildHeader(isDarkMode),
                    const SizedBox(height: 12),
                  ],
                );
              }

              final log = logs[index - 1];
              final id = log["id"].toString();
              final isSelected = selectedIds.contains(id);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
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
                        child: buildLogCard(
                          log: log,
                          isDarkMode: isDarkMode,
                          isSelected: isSelected,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
          ),
    );
  }
}