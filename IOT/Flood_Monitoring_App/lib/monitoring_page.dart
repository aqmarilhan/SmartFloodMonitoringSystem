import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dashboard_page.dart';

class FloodMonitoringPage extends StatefulWidget {
  const FloodMonitoringPage({super.key});

  @override
  State<FloodMonitoringPage> createState() => _FloodMonitoringPageState();
}

class _FloodMonitoringPageState extends State<FloodMonitoringPage> {

  final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

  late FirebaseDatabase database;
  late DatabaseReference floodRef;
  late DatabaseReference statsRef;

  Future<void> initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await notifications.initialize(settings);
  }

  String distance = "--";
  String waterHeightCm = "--";
  String waterLevel = "--";
  String floodStatus = "--";
  String ledStatus = "--";
  String lastUpdated = "--";
  String previousStatus = "";

  int warningCount = 0;
  int dangerousCount = 0;

  bool firebaseConnected = true;
  bool notificationsEnabled = true;

  double bucketDepth = 34.0;
  double warningWaterHeight = 10.0;
  double dangerWaterHeight = 13.5;

  @override
  void initState() {
    super.initState();

    initializeNotifications();

  database = FirebaseDatabase.instanceFor(
  app: Firebase.app(),
  databaseURL:
      "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app",
);

    floodRef = database.ref("FloodMonitoring");
    statsRef = database.ref("Statistics");

    database.ref("Settings").onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        final settings = Map<dynamic, dynamic>.from(data);
        if (!mounted) return;
        setState(() {
          bucketDepth = double.tryParse(settings["bucketDepth"]?.toString() ?? "") ?? 34.0;
          warningWaterHeight = double.tryParse(settings["warningWaterHeight"]?.toString() ?? "") ?? 10.0;
          dangerWaterHeight = double.tryParse(settings["dangerWaterHeight"]?.toString() ?? "") ?? 13.5;
        });
      }
    });

    statsRef.once().then((snapshot) {

      final data = snapshot.snapshot.value;

      if (data != null && data is Map) {

        setState(() {

          warningCount =
              data["warningCount"] ?? 0;

          dangerousCount =
              data["dangerousCount"] ?? 0;

        });
      }
});

    debugPrint("Listener Started");

  floodRef.onValue.listen((event) {

   debugPrint("Firebase Data:");
   debugPrint(event.snapshot.value.toString());

  final data = event.snapshot.value;

  debugPrint("Firebase Data:");
  debugPrint(data.toString());

if (data != null && data is Map) {

  String newStatus =
      data["flood_status"]?.toString() ?? "--";

  if (newStatus != previousStatus) {

  if (newStatus == "WARNING") {

    warningCount++;

    statsRef.child("warningCount")
        .set(warningCount);

    if (DashboardPage.notificationsEnabled) {
      showNotification(
        "⚠️ Flood Warning",
        "Water level is increasing. Stay alert.",
      );
    }
  }

  else if (newStatus == "DANGEROUS") {

    dangerousCount++;

    statsRef.child("dangerousCount")
        .set(dangerousCount);

    if (DashboardPage.notificationsEnabled) {
      showNotification(
        "🚨 Flood Alert",
        "Dangerous flood level detected! Move vehicle immediately.",
      );
    }
  }

  previousStatus = newStatus;
}

  setState(() {

    distance =
        data["distance_cm"]?.toString() ?? "--";

    waterHeightCm =
        data["water_height_cm"]?.toString() ?? "--";

    waterLevel =
        data["water_level"]?.toString() ?? "--";

    floodStatus = newStatus;

    ledStatus =
        data["led_indicator_status"]?.toString() ?? "--";

    lastUpdated =
        DateTime.now().toString().substring(0, 19);
  });
}
}); // closes floodRef.onValue.listen
}   // closes initState

  Future<void> showNotification(String title,String body,) 

  async {
  const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
        'flood_alerts',
        'Flood Alerts',
        channelDescription: 'Flood monitoring alerts',
        importance: Importance.max,
        priority: Priority.high,
      );

  const NotificationDetails notificationDetails =
      NotificationDetails(
        android: androidDetails,
      );
      
  debugPrint("SHOWING NOTIFICATION");

  await notifications.show(
    0,
    title,
    body,
    notificationDetails,
  );
}

  double getDistanceValue() {
    return double.tryParse(distance) ?? 0.0;
  }

  int getWaterValue() {
    return int.tryParse(waterLevel) ?? 0;
  }

  Color getStatusColor() {
    if (floodStatus == "SAFE") {
      return Colors.green;
    } else if (floodStatus == "WARNING") {
      return Colors.orange;
    } else if (floodStatus == "DANGEROUS") {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }

  String getStatusDescription() {
    if (floodStatus == "SAFE") {
      return "No flood risk detected. Your vehicle area is currently safe.";
    } else if (floodStatus == "WARNING") {
      return "Water level is rising. Please monitor the vehicle area.";
    } else if (floodStatus == "DANGEROUS") {
      return "Dangerous water level detected. Move your vehicle immediately.";
    } else {
      return "Waiting for sensor data from the device.";
    }
  }

  String getDistanceCondition() {
    if (floodStatus == "SAFE") {
      return "Safe level";
    } else if (floodStatus == "WARNING") {
      return "Warning level";
    } else if (floodStatus == "DANGEROUS") {
      return "Danger level";
    } else {
      return "Loading status...";
    }
  }

  String getDistanceDescription() {
    final height = double.tryParse(waterHeightCm) ?? 0.0;
    if (floodStatus == "SAFE") {
      return "Water height is at ${height.toStringAsFixed(1)} cm. The level is normal (below warning threshold of ${warningWaterHeight.toStringAsFixed(1)} cm).";
    } else if (floodStatus == "WARNING") {
      final excess = height - warningWaterHeight;
      return "Water height is at ${height.toStringAsFixed(1)} cm, exceeding the warning threshold of ${warningWaterHeight.toStringAsFixed(1)} cm by ${excess.toStringAsFixed(1)} cm!";
    } else if (floodStatus == "DANGEROUS") {
      final excess = height - dangerWaterHeight;
      return "🚨 CRITICAL: Water height is at ${height.toStringAsFixed(1)} cm, exceeding the danger threshold of ${dangerWaterHeight.toStringAsFixed(1)} cm by ${excess.toStringAsFixed(1)} cm! Move vehicles immediately.";
    } else {
      return "Waiting for telemetry updates...";
    }
  }

  Color getDistanceColor() {
    if (floodStatus == "SAFE") {
      return Colors.green;
    } else if (floodStatus == "WARNING") {
      return Colors.orange;
    } else if (floodStatus == "DANGEROUS") {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }

  String getWaterSensorDisplay() {
    final value = getWaterValue();
    if (value < 1000) {
      return "Dry (0%)";
    } else if (value < 1700) {
      final percentage = (50 + ((value - 1000) / 700.0) * 30).clamp(50.0, 80.0);
      return "Wet (${percentage.toStringAsFixed(0)}%)";
    } else {
      final percentage = (80 + ((value - 1700) / (4095 - 1700.0)) * 20).clamp(80.0, 100.0);
      return "Submerged (${percentage.toStringAsFixed(0)}%)";
    }
  }

  String getWaterCondition() {
    final value = getWaterValue();
    if (value < 1000) {
      return "Sensor is dry";
    } else if (value < 1700) {
      return "Water contact detected";
    } else {
      return "Sensor submerged";
    }
  }

  String getWaterDescription() {
    final value = getWaterValue();
    if (value < 1000) {
      return "Moisture level is normal. No physical water contact detected at the 13.5 cm warning level.";
    } else if (value < 1700) {
      return "Active contact: The physical sensor at 13.5 cm is touching rising water.";
    } else {
      return "🚨 CRITICAL: The physical water sensor is completely submerged under water.";
    }
  }

  Color getWaterColor() {
    final value = getWaterValue();

    if (value < 1000) {
      return Colors.green;
    } else if (value < 1700) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Widget buildSensorInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required String condition,
    required String description,
    required Color color,
  }) {
    final isDarkMode =
        Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF1E293B).withOpacity(0.7)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withOpacity(0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
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

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                    letterSpacing: -0.2,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: color.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    condition.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

IconData getStatusIcon() {
  if (floodStatus == "SAFE") {
    return Icons.check_circle_rounded;
  } else if (floodStatus == "WARNING") {
    return Icons.warning_amber_rounded;
  } else if (floodStatus == "DANGEROUS") {
    return Icons.dangerous_rounded;
  } else {
    return Icons.sensors;
  }
}

Widget buildModernStatusHeader() {
  Color statusColor = getStatusColor();
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          statusColor,
          statusColor.withOpacity(0.75),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: statusColor.withOpacity(0.35),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Icon(
            getStatusIcon(),
            size: 36,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          floodStatus,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          getStatusDescription(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.45,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}

Widget buildSensorGuideCard() {
  final isDarkMode =
      Theme.of(context).brightness == Brightness.dark;

  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: isDarkMode
          ? const Color(0xFF1E293B).withOpacity(0.7)
          : Colors.white.withOpacity(0.9),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: isDarkMode
            ? Colors.lightBlueAccent.withOpacity(0.25)
            : Colors.blue.withOpacity(0.2),
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
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.lightBlueAccent.withOpacity(0.15)
                : Colors.blue.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDarkMode ? Colors.lightBlueAccent.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.info_outline_rounded,
            color: isDarkMode
                ? Colors.lightBlueAccent
                : Colors.blue,
            size: 22,
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Sensor Diagnostics Guide",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "• Lower distance means the water is rising.\n"
                "• Higher water reading means more water is detected.\n"
                "• Green means safe, orange warning, and red dangerous.",
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDarkMode
                      ? Colors.grey.shade300
                      : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: isDarkMode ? Colors.white : Colors.black87,
        title: const Text(
          "Smart Flood Monitoring",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildModernStatusHeader(),

                const SizedBox(height: 18),

                buildSensorGuideCard(),

                const SizedBox(height: 18),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF1E293B).withOpacity(0.7)
                        : Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: getStatusColor().withOpacity(0.35),
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
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: getStatusColor().withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: getStatusColor().withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          getStatusIcon(),
                          color: getStatusColor(),
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Current Flood Status",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              floodStatus,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: getStatusColor(),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                buildSensorInfoCard(
                  icon: Icons.height_rounded,
                  title: "Water Height (from bottom)",
                  value:
                      "${double.tryParse(waterHeightCm)?.toStringAsFixed(1) ?? waterHeightCm} cm",
                  condition: getDistanceCondition(),
                  description: getDistanceDescription(),
                  color: getDistanceColor(),
                ),

                buildSensorInfoCard(
                  icon: Icons.opacity_rounded,
                  title: "Moisture Contact Sensor",
                  value: getWaterSensorDisplay(),
                  condition: getWaterCondition(),
                  description: getWaterDescription(),
                  color: getWaterColor(),
                ),

                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isDarkMode ? const Color(0xFF8B5CF6) : const Color(0xFF4F46E5)).withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (isDarkMode ? const Color(0xFF8B5CF6) : const Color(0xFF4F46E5)).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.access_time_rounded,
                          color: isDarkMode ? const Color(0xFFC084FC) : const Color(0xFF4F46E5),
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Last Updated",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              lastUpdated,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}