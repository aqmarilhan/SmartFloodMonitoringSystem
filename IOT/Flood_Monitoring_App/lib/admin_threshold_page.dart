import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminThresholdPage extends StatefulWidget {
  const AdminThresholdPage({super.key});

  @override
  State<AdminThresholdPage> createState() => _AdminThresholdPageState();
}

class _AdminThresholdPageState extends State<AdminThresholdPage> {
  final String databaseURL =
      "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app/";

  late final DatabaseReference settingsRef;

  final TextEditingController bucketDepthController =
      TextEditingController();

  final TextEditingController warningHeightController =
      TextEditingController();

  final TextEditingController dangerHeightController =
      TextEditingController();

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    settingsRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: databaseURL,
    ).ref("Settings");

    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final snapshot = await settingsRef.get().timeout(const Duration(seconds: 10));

      if (snapshot.exists && snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);

        bucketDepthController.text =
            data["bucketDepth"]?.toString() ?? "28";

        warningHeightController.text =
            data["warningWaterHeight"]?.toString() ?? "9";

        dangerHeightController.text =
            data["dangerWaterHeight"]?.toString() ?? "13";
      } else {
        bucketDepthController.text = "28";
        warningHeightController.text = "9";
        dangerHeightController.text = "13";
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to load settings: $e"),
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  Future<void> saveSettings() async {
    final double? bucketDepth =
        double.tryParse(bucketDepthController.text.trim());

    final double? warningHeight =
        double.tryParse(warningHeightController.text.trim());

    final double? dangerHeight =
        double.tryParse(dangerHeightController.text.trim());

    if (bucketDepth == null ||
        warningHeight == null ||
        dangerHeight == null) {
      showMessage("Please enter valid numbers.");
      return;
    }

    if (bucketDepth <= 0 || warningHeight <= 0 || dangerHeight <= 0) {
      showMessage("All values must be greater than 0.");
      return;
    }

    if (warningHeight >= dangerHeight) {
      showMessage("Warning level must be lower than danger level.");
      return;
    }

    if (dangerHeight >= bucketDepth) {
      showMessage("Danger level must be lower than bucket depth.");
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      await settingsRef.update({
        "bucketDepth": bucketDepth,
        "warningWaterHeight": warningHeight,
        "dangerWaterHeight": dangerHeight,
        "updatedBy": user?.email ?? "Unknown user",
        "updatedAt": DateTime.now().toString(),
      });

      final auditRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: databaseURL,
      ).ref("AuditLogs").push();

      await auditRef.set({
        "action": "Threshold calibration updated",
        "details":
            "Bucket depth: $bucketDepth cm, Warning: $warningHeight cm, Danger: $dangerHeight cm",
        "severity": "MEDIUM",
        "source": user?.email ?? "Unknown user",
        "category": "ADMIN",
        "timestamp": DateTime.now().toString(),
        "createdAtEpoch": DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });

      if (!mounted) return;

      showMessage("Threshold settings updated successfully.");
    } catch (e) {
      if (!mounted) return;

      showMessage("Failed to save settings: $e");
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
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

  Widget buildHeader(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [
                  const Color(0xFF312E81),
                  const Color(0xFF0F172A),
                ]
              : [
                  Colors.deepPurple,
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
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Colors.white,
              size: 70,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Threshold Calibration",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Adjust flood detection levels without modifying ESP32 code",
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
            Icons.info_outline,
            color: Colors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "These values are stored in Firebase. ESP32 will read the latest settings and update the flood detection threshold automatically.",
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

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
        ),
        style: TextStyle(
          color: getMainTextColor(isDarkMode),
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixText: "cm",
          prefixIcon: Icon(icon),
          filled: true,
          fillColor:
              isDarkMode ? const Color(0xFF0F172A) : Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: Colors.deepPurple,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildExampleCard(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Current Bucket Example",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: getMainTextColor(isDarkMode),
            ),
          ),
          const SizedBox(height: 14),
          exampleRow(
            icon: Icons.height,
            title: "Bucket depth",
            value: "28 cm",
            color: Colors.blue,
            isDarkMode: isDarkMode,
          ),
          exampleRow(
            icon: Icons.warning_amber_rounded,
            title: "Warning level",
            value: "9 cm",
            color: Colors.orange,
            isDarkMode: isDarkMode,
          ),
          exampleRow(
            icon: Icons.dangerous_rounded,
            title: "Danger level",
            value: "13 cm",
            color: Colors.red,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget exampleRow({
    required IconData icon,
    required String title,
    required String value,
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
              title,
              style: TextStyle(
                color: getSubTextColor(isDarkMode),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: getMainTextColor(isDarkMode),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    bucketDepthController.dispose();
    warningHeightController.dispose();
    dangerHeightController.dispose();
    super.dispose();
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
        title: const Text("Threshold Calibration"),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  buildHeader(isDarkMode),

                  const SizedBox(height: 18),

                  buildInfoBox(isDarkMode),

                  const SizedBox(height: 18),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: getCardColor(isDarkMode),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            isDarkMode ? 0.25 : 0.08,
                          ),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        buildTextField(
                          controller: bucketDepthController,
                          label: "Bucket Depth",
                          hint: "Example: 28",
                          icon: Icons.height,
                          isDarkMode: isDarkMode,
                        ),
                        buildTextField(
                          controller: warningHeightController,
                          label: "Warning Water Height",
                          hint: "Example: 9",
                          icon: Icons.warning_amber_rounded,
                          isDarkMode: isDarkMode,
                        ),
                        buildTextField(
                          controller: dangerHeightController,
                          label: "Danger Water Height",
                          hint: "Example: 13",
                          icon: Icons.dangerous_rounded,
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: isSaving ? null : saveSettings,
                            icon: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(
                              isSaving
                                  ? "Saving..."
                                  : "Save Threshold Settings",
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  buildExampleCard(isDarkMode),
                ],
              ),
            ),
    );
  }
}