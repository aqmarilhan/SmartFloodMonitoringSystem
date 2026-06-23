import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class RegisterVehiclePage extends StatefulWidget {
  const RegisterVehiclePage({super.key});

  @override
  State<RegisterVehiclePage> createState() => _RegisterVehiclePageState();
}

class _RegisterVehiclePageState extends State<RegisterVehiclePage> {
  final TextEditingController plateController = TextEditingController();
  final TextEditingController brandController = TextEditingController();
  final TextEditingController modelController = TextEditingController();
  final TextEditingController colorController = TextEditingController();
  final TextEditingController parkingLocationController =
      TextEditingController();

  bool isSaving = false;

  final String databaseURL =
      "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app";

  FirebaseDatabase get database {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: databaseURL,
    );
  }

  DatabaseReference get vehiclesRef {
    final user = FirebaseAuth.instance.currentUser;
    return database.ref("Vehicles/${user!.uid}");
  }

  @override
  void dispose() {
    plateController.dispose();
    brandController.dispose();
    modelController.dispose();
    colorController.dispose();
    parkingLocationController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> saveVehicle() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage("Please login first.");
      return;
    }

    final plateNumber = plateController.text.trim().toUpperCase();
    final brand = brandController.text.trim();
    final model = modelController.text.trim();
    final color = colorController.text.trim();
    final parkingLocation = parkingLocationController.text.trim();

    String ownerUsername = "Unknown User";

    final userSnapshot = await database
        .ref("Users/${user.uid}")
        .get()
        .timeout(const Duration(seconds: 10));

    if (userSnapshot.exists && userSnapshot.value != null) {
      final userData = Map<dynamic, dynamic>.from(userSnapshot.value as Map);
      ownerUsername = userData["username"]?.toString() ?? "Unknown User";
    }

    if (plateNumber.isEmpty ||
        brand.isEmpty ||
        model.isEmpty ||
        color.isEmpty ||
        parkingLocation.isEmpty) {
      showMessage("Please fill all vehicle details.");
      return;
    }

    if (plateNumber.length < 3) {
      showMessage("Please enter a valid plate number.");
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final existingSnapshot =
          await vehiclesRef.get().timeout(const Duration(seconds: 10));

      if (existingSnapshot.exists && existingSnapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(
          existingSnapshot.value as Map,
        );

        bool plateExists = false;

        data.forEach((key, value) {
          final vehicle = Map<dynamic, dynamic>.from(value);

          final existingPlate =
              vehicle["plateNumber"]?.toString().toUpperCase() ?? "";

          if (existingPlate == plateNumber) {
            plateExists = true;
          }
        });

        if (plateExists) {
          if (!mounted) return;

          setState(() {
            isSaving = false;
          });

          showMessage("This vehicle plate number is already registered.");
          return;
        }
      }

      final newVehicleRef = vehiclesRef.push();

      await newVehicleRef.set({
        "vehicleId": newVehicleRef.key,

        "ownerUid": user.uid,
        "ownerEmail": user.email ?? "Unknown email",
        "ownerUsername": ownerUsername,

        "plateNumber": plateNumber,
        "brand": brand,
        "model": model,
        "color": color,
        "parkingLocation": parkingLocation,
        "status": "Active",

        "createdAt": DateTime.now().toString(),
        "createdAtEpoch": DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });

      await database.ref("Users/${user.uid}").update({
        "hasVehicle": true,
        "updatedAt": DateTime.now().toString(),
      });

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      plateController.clear();
      brandController.clear();
      modelController.clear();
      colorController.clear();
      parkingLocationController.clear();

      showMessage("Vehicle registered successfully.");
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      showMessage("Failed to register vehicle: $e");
    }
  }

  Future<void> deleteVehicle({
    required String vehicleId,
    required String plateNumber,
  }) async {
    try {
      await vehiclesRef.child(vehicleId).remove();

      if (!mounted) return;

      showMessage("$plateNumber deleted successfully.");
    } catch (e) {
      if (!mounted) return;

      showMessage("Failed to delete vehicle: $e");
    }
  }

  void showDeleteDialog({
    required String vehicleId,
    required String plateNumber,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Delete Vehicle"),
          content: Text("Delete vehicle $plateNumber?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);

                await deleteVehicle(
                  vehicleId: vehicleId,
                  plateNumber: plateNumber,
                );
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
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
                  const Color(0xFF1E3A8A),
                  const Color(0xFF0F172A),
                ]
              : [
                  Colors.lightBlue,
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
              Icons.directions_car_rounded,
              color: Colors.white,
              size: 70,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Register Vehicle",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Add your vehicle details for flood monitoring and early warning records",
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

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDarkMode,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        textCapitalization: textCapitalization,
        style: TextStyle(
          color: getMainTextColor(isDarkMode),
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
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
              color: Colors.lightBlue,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildFormCard(bool isDarkMode) {
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
        children: [
          buildTextField(
            controller: plateController,
            label: "Plate Number",
            hint: "Example: JBC 1234",
            icon: Icons.pin_rounded,
            isDarkMode: isDarkMode,
            textCapitalization: TextCapitalization.characters,
          ),
          buildTextField(
            controller: brandController,
            label: "Vehicle Brand",
            hint: "Example: Proton",
            icon: Icons.factory_rounded,
            isDarkMode: isDarkMode,
          ),
          buildTextField(
            controller: modelController,
            label: "Vehicle Model",
            hint: "Example: Saga",
            icon: Icons.directions_car_filled_rounded,
            isDarkMode: isDarkMode,
          ),
          buildTextField(
            controller: colorController,
            label: "Vehicle Color",
            hint: "Example: White",
            icon: Icons.color_lens_rounded,
            isDarkMode: isDarkMode,
          ),
          buildTextField(
            controller: parkingLocationController,
            label: "Parking Location",
            hint: "Example: UTM Parking Block A",
            icon: Icons.location_on_rounded,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : saveVehicle,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                isSaving ? "Saving..." : "Register Vehicle",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildVehicleCard({
    required String vehicleId,
    required Map<dynamic, dynamic> vehicle,
    required bool isDarkMode,
  }) {
    final plateNumber = vehicle["plateNumber"]?.toString() ?? "--";
    final brand = vehicle["brand"]?.toString() ?? "--";
    final model = vehicle["model"]?.toString() ?? "--";
    final color = vehicle["color"]?.toString() ?? "--";
    final parkingLocation = vehicle["parkingLocation"]?.toString() ?? "--";
    final status = vehicle["status"]?.toString() ?? "Active";
    final ownerUsername = vehicle["ownerUsername"]?.toString() ?? "--";
    final ownerEmail = vehicle["ownerEmail"]?.toString() ?? "--";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getCardColor(isDarkMode),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.lightBlue.withOpacity(0.22),
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
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.lightBlue.withOpacity(0.15),
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: Colors.lightBlue,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plateNumber,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: getMainTextColor(isDarkMode),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$brand $model",
                      style: TextStyle(
                        color: getSubTextColor(isDarkMode),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.green,
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
          vehicleInfoRow(
            icon: Icons.color_lens_rounded,
            title: "Color",
            value: color,
            isDarkMode: isDarkMode,
          ),
          vehicleInfoRow(
            icon: Icons.location_on_rounded,
            title: "Parking Location",
            value: parkingLocation,
            isDarkMode: isDarkMode,
          ),
          vehicleInfoRow(
            icon: Icons.person_rounded,
            title: "Owner",
            value: ownerUsername,
            isDarkMode: isDarkMode,
          ),
          vehicleInfoRow(
            icon: Icons.email_rounded,
            title: "Owner Email",
            value: ownerEmail,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.delete_rounded),
              label: const Text("Delete Vehicle"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                showDeleteDialog(
                  vehicleId: vehicleId,
                  plateNumber: plateNumber,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget vehicleInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required bool isDarkMode,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: Colors.lightBlue,
          ),
          const SizedBox(width: 8),
          Text(
            "$title: ",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: getSubTextColor(isDarkMode),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: getMainTextColor(isDarkMode),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildVehicleList(bool isDarkMode) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Text(
        "Please login to view registered vehicles.",
        style: TextStyle(
          color: getSubTextColor(isDarkMode),
        ),
      );
    }

    return StreamBuilder<DatabaseEvent>(
      stream: vehiclesRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: getCardColor(isDarkMode),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                "Error loading vehicles: ${snapshot.error}",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final data = snapshot.data!.snapshot.value;

        if (data == null) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: getCardColor(isDarkMode),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.no_crash_rounded,
                  size: 60,
                  color: getSubTextColor(isDarkMode),
                ),
                const SizedBox(height: 12),
                Text(
                  "No vehicle registered yet",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: getMainTextColor(isDarkMode),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Your registered vehicles will appear here.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: getSubTextColor(isDarkMode),
                  ),
                ),
              ],
            ),
          );
        }

        final vehicles = Map<dynamic, dynamic>.from(data as Map);
        final keys = vehicles.keys.toList();

        return Column(
          children: keys.map((key) {
            final vehicle = Map<dynamic, dynamic>.from(
              vehicles[key],
            );

            return buildVehicleCard(
              vehicleId: key.toString(),
              vehicle: vehicle,
              isDarkMode: isDarkMode,
            );
          }).toList(),
        );
      },
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
        title: const Text("Register Vehicle"),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
        children: [
          buildHeader(isDarkMode),

          const SizedBox(height: 18),

          buildFormCard(isDarkMode),

          const SizedBox(height: 24),

          Text(
            "My Registered Vehicles",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: getMainTextColor(isDarkMode),
            ),
          ),

          const SizedBox(height: 14),

          buildVehicleList(isDarkMode),
        ],
      ),
          ),
    );
  }
}