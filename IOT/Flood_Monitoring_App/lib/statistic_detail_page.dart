import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class StatisticDetailPage extends StatefulWidget {
  final String statusFilter;
  final String title;
  final Color color;
  final IconData icon;

  const StatisticDetailPage({
    super.key,
    required this.statusFilter,
    required this.title,
    required this.color,
    required this.icon,
  });

  @override
  State<StatisticDetailPage> createState() => _StatisticDetailPageState();
}

class _StatisticDetailPageState extends State<StatisticDetailPage> {
  final String databaseURL =
      "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app";

  FirebaseDatabase get database {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: databaseURL,
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

  List<Map<String, dynamic>> filterHistory(dynamic data) {
    final List<Map<String, dynamic>> records = [];

    if (data == null || data is! Map) {
      return records;
    }

    final historyMap = Map<dynamic, dynamic>.from(data);

    historyMap.forEach((key, value) {
      if (value is Map) {
        final item = Map<dynamic, dynamic>.from(value);

        final status = item["flood_status"]?.toString().toUpperCase() ?? "";

        if (status == widget.statusFilter.toUpperCase()) {
          records.add({
            "id": key.toString(),
            "distance_cm": double.tryParse(item["distance_cm"]?.toString() ?? "")?.toStringAsFixed(1) ?? item["distance_cm"]?.toString() ?? "--",
            "water_height_cm": double.tryParse(item["water_height_cm"]?.toString() ?? "")?.toStringAsFixed(1) ?? item["water_height_cm"]?.toString() ?? "--",
            "water_level": item["water_level"]?.toString() ?? "--",
            "flood_status": item["flood_status"]?.toString() ?? "--",
            "led_indicator_status":
                item["led_indicator_status"]?.toString() ?? "--",
            "timestamp": item["timestamp"]?.toString() ?? "No Time",
          });
        }
      }
    });

    records.sort((a, b) {
      return b["id"].toString().compareTo(a["id"].toString());
    });

    return records;
  }

  Widget buildHeader(bool isDarkMode, int totalRecords) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.color,
            widget.color.withOpacity(0.65),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            widget.icon,
            color: Colors.white,
            size: 58,
          ),
          const SizedBox(height: 12),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "$totalRecords recorded event(s)",
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRecordCard(
    Map<String, dynamic> record,
    bool isDarkMode,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: getCardColor(isDarkMode),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.color.withOpacity(0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                widget.icon,
                color: widget.color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  record["flood_status"],
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              Text(
                record["timestamp"],
                style: TextStyle(
                  color: getSubTextColor(isDarkMode),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          infoRow(
            icon: Icons.straighten_rounded,
            title: "Distance",
            value: "${record["distance_cm"]} cm",
            isDarkMode: isDarkMode,
          ),
          infoRow(
            icon: Icons.water_drop_rounded,
            title: "Water Height",
            value: "${record["water_height_cm"]} cm",
            isDarkMode: isDarkMode,
          ),
          infoRow(
            icon: Icons.sensors_rounded,
            title: "Water Sensor",
            value: record["water_level"],
            isDarkMode: isDarkMode,
          ),
          infoRow(
            icon: Icons.lightbulb_rounded,
            title: "LED Status",
            value: record["led_indicator_status"],
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget infoRow({
    required IconData icon,
    required String title,
    required String value,
    required bool isDarkMode,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(
            icon,
            color: widget.color,
            size: 21,
          ),
          const SizedBox(width: 8),
          Text(
            "$title: ",
            style: TextStyle(
              color: getSubTextColor(isDarkMode),
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: getMainTextColor(isDarkMode),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyState(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: getCardColor(isDarkMode),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.folder_off_rounded,
            color: getSubTextColor(isDarkMode),
            size: 60,
          ),
          const SizedBox(height: 12),
          Text(
            "No ${widget.statusFilter} records found",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: getMainTextColor(isDarkMode),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Records will appear here when the ESP32 saves ${widget.statusFilter} events into Firebase History.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: getSubTextColor(isDarkMode),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: getBackgroundColor(isDarkMode),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: getBackgroundColor(isDarkMode),
        foregroundColor: getMainTextColor(isDarkMode),
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: database.ref("History").onValue,
        builder: (context, snapshot) {
          final records = filterHistory(snapshot.data?.snapshot.value);

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                buildHeader(isDarkMode, records.length),
                const SizedBox(height: 18),
                records.isEmpty
                    ? buildEmptyState(isDarkMode)
                    : Column(
                        children: records
                            .map(
                              (record) => buildRecordCard(
                                record,
                                isDarkMode,
                              ),
                            )
                            .toList(),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
