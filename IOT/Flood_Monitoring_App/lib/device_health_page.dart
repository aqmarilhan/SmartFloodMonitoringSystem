import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class DeviceHealthPage extends StatelessWidget {
  const DeviceHealthPage({super.key});

  DatabaseReference get deviceRef => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app/",
      ).ref("DeviceStatus");

  String getText(Map data, String key) {
    return data[key]?.toString() ?? "--";
  }

  int getInt(Map data, String key) {
    final value = data[key];

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? "") ?? 0;
  }

  bool isDeviceOnline(Map data) {
    final lastSeenEpoch = getInt(data, "last_seen_epoch");

    if (lastSeenEpoch == 0) {
      return data["online"] == true;
    }

    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final difference = nowEpoch - lastSeenEpoch;

    return difference <= 60;
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

  Color getHealthColor(String value) {
    final text = value.toUpperCase();

    if (text.contains("OK") ||
        text.contains("GOOD") ||
        text.contains("EXCELLENT") ||
        text.contains("NORMAL") ||
        text.contains("SAFE")) {
      return Colors.green;
    }

    if (text.contains("FAIR") ||
        text.contains("WEAK") ||
        text.contains("BACKUP") ||
        text.contains("SUSPECTED") ||
        text.contains("WARNING")) {
      return Colors.orange;
    }

    if (text.contains("FAULT") ||
        text.contains("CHECK") ||
        text.contains("SHORT") ||
        text.contains("DANGEROUS")) {
      return Colors.redAccent;
    }

    return Colors.grey;
  }

  IconData getHealthIcon(String title) {
    if (title.contains("Last Seen")) {
      return Icons.access_time_rounded;
    }

    if (title.contains("WiFi")) {
      return Icons.wifi_rounded;
    }

    if (title.contains("Water")) {
      return Icons.water_drop_rounded;
    }

    if (title.contains("Ultrasonic")) {
      return Icons.sensors_rounded;
    }

    if (title.contains("Backup")) {
      return Icons.backup_rounded;
    }

    if (title.contains("Flood")) {
      return Icons.warning_amber_rounded;
    }

    return Icons.memory_rounded;
  }

  Widget buildHeader({
    required bool online,
    required String deviceName,
    required bool isDarkMode,
  }) {
    final statusColor = online ? Colors.green : Colors.redAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: online
              ? isDarkMode
                  ? [
                      const Color(0xFF14532D),
                      const Color(0xFF0F172A),
                    ]
                  : [
                      Colors.green,
                      Colors.lightGreen,
                    ]
              : isDarkMode
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
            child: Icon(
              online ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white,
              size: 70,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            deviceName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            online
                ? "Device is online and sending health data"
                : "Device is offline or not recently updated",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: Colors.white.withOpacity(0.88),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              online ? "ONLINE" : "OFFLINE",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                shadows: [
                  Shadow(
                    color: statusColor.withOpacity(0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget healthCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getCardColor(isDarkMode),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withOpacity(0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(
              icon,
              color: color,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: getSubTextColor(isDarkMode),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInfoBox(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.blue.withOpacity(0.12)
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.blue.withOpacity(0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Colors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Device health is updated by ESP32. If the device appears offline, check WiFi connection, Firebase connection, or ESP32 power supply.",
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

  Widget buildEmptyState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.memory_rounded,
              size: 80,
              color: getSubTextColor(isDarkMode),
            ),
            const SizedBox(height: 16),
            Text(
              "No device health data found",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: getMainTextColor(isDarkMode),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Upload device health data from ESP32 to Firebase first.",
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
        title: const Text("Device Health"),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: StreamBuilder<DatabaseEvent>(
          stream: deviceRef.onValue,
          builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "Error loading health data: ${snapshot.error}",
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

          final data = Map<dynamic, dynamic>.from(
            snapshot.data!.snapshot.value as Map,
          );

          final online = isDeviceOnline(data);

          final deviceName = getText(data, "device_name");
          final lastSeen = getText(data, "last_seen");
          final wifiRssi = getText(data, "wifi_rssi");
          final wifiQuality = getText(data, "wifi_quality");
          final waterSensorStatus = getText(data, "water_sensor_status");
          final ultrasonicStatus = getText(data, "ultrasonic_status");
          final backupMode = getText(data, "backup_mode");
          final currentStatus = getText(data, "current_status");

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            children: [
              buildHeader(
                online: online,
                deviceName: deviceName,
                isDarkMode: isDarkMode,
              ),

              const SizedBox(height: 18),

              buildInfoBox(isDarkMode),

              const SizedBox(height: 18),

              healthCard(
                icon: Icons.access_time_rounded,
                title: "Last Seen",
                value: lastSeen,
                color: online ? Colors.green : Colors.redAccent,
                isDarkMode: isDarkMode,
              ),

              healthCard(
                icon: Icons.wifi_rounded,
                title: "WiFi Signal",
                value: "$wifiQuality ($wifiRssi dBm)",
                color: getHealthColor(wifiQuality),
                isDarkMode: isDarkMode,
              ),

              healthCard(
                icon: Icons.water_drop_rounded,
                title: "Water Sensor Status",
                value: waterSensorStatus,
                color: getHealthColor(waterSensorStatus),
                isDarkMode: isDarkMode,
              ),

              healthCard(
                icon: Icons.sensors_rounded,
                title: "Ultrasonic Sensor Status",
                value: ultrasonicStatus,
                color: getHealthColor(ultrasonicStatus),
                isDarkMode: isDarkMode,
              ),

              healthCard(
                icon: Icons.backup_rounded,
                title: "Backup Mode",
                value: backupMode,
                color: getHealthColor(backupMode),
                isDarkMode: isDarkMode,
              ),

              healthCard(
                icon: Icons.warning_amber_rounded,
                title: "Current Flood Status",
                value: currentStatus,
                color: getHealthColor(currentStatus),
                isDarkMode: isDarkMode,
              ),
            ],
          );
        },
      ),
          ),
    );
  }
}