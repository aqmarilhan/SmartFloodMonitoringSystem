import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class VehicleLocationPage extends StatefulWidget {
  const VehicleLocationPage({super.key});

  @override
  State<VehicleLocationPage> createState() => _VehicleLocationPageState();
}

class _VehicleLocationPageState extends State<VehicleLocationPage> {
  final String databaseURL =
      "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app";

  bool isLoading = true;
  bool isSavingLocation = false;

  Map<String, dynamic> vehicles = {};
  String? selectedVehicleId;

  final double defaultLatitude = 1.5586;
  final double defaultLongitude = 103.6375;

  GoogleMapController? _mapController;

  FirebaseDatabase get database {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: databaseURL,
    );
  }

  @override
  void initState() {
    super.initState();
    loadVehicles();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _updateMapCamera() {
    if (_mapController != null && hasVehicleLocation()) {
      final lat = getSelectedLatitude();
      final lng = getSelectedLongitude();
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(lat, lng),
          15.0,
        ),
      );
    }
  }

  Future<void> loadVehicles() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        vehicles = {};
        selectedVehicleId = null;
        isLoading = false;
      });

      showMessage("User not logged in.");
      return;
    }

    try {
      final ref = database.ref("Vehicles/${user.uid}");

      final snapshot = await ref.get().timeout(
            const Duration(seconds: 10),
          );

      if (!mounted) return;

      if (snapshot.exists && snapshot.value != null) {
        final rawData = Map<dynamic, dynamic>.from(snapshot.value as Map);

        final convertedData = rawData.map(
          (key, value) => MapEntry(
            key.toString(),
            value,
          ),
        );

        setState(() {
          vehicles = convertedData;
          selectedVehicleId =
              convertedData.isNotEmpty ? convertedData.keys.first : null;
          isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateMapCamera();
        });
      } else {
        setState(() {
          vehicles = {};
          selectedVehicleId = null;
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        vehicles = {};
        selectedVehicleId = null;
        isLoading = false;
      });

      showMessage("Failed to load vehicles: $e");
    }
  }

  Future<Position?> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      showMessage("Please enable location service.");
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      showMessage("Location permission denied.");
      return null;
    }

    if (permission == LocationPermission.deniedForever) {
      showMessage(
        "Location permission permanently denied. Please enable it in settings.",
      );
      return null;
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    ).timeout(
      const Duration(seconds: 15),
    );
  }

  Future<void> saveCurrentLocation() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage("User not logged in.");
      return;
    }

    if (selectedVehicleId == null) {
      showMessage("Please register a vehicle first.");
      return;
    }

    setState(() {
      isSavingLocation = true;
    });

    try {
      final position = await getCurrentPosition();

      if (position == null) {
        if (!mounted) return;

        setState(() {
          isSavingLocation = false;
        });

        return;
      }

      final ref = database.ref("Vehicles/${user.uid}/$selectedVehicleId");

      await ref.update({
        "latitude": position.latitude,
        "longitude": position.longitude,
        "locationUpdatedAt": DateTime.now().toString(),
        "locationUpdatedAtEpoch": DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });

      await loadVehicles();

      if (!mounted) return;

      setState(() {
        isSavingLocation = false;
      });

      showMessage("Vehicle location updated successfully.");
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSavingLocation = false;
      });

      showMessage("Failed to update location: $e");
    }
  }

  Future<void> openGoogleMaps() async {
    if (!hasVehicleLocation()) {
      showMessage("Please save vehicle location first.");
      return;
    }

    final latitude = getSelectedLatitude();
    final longitude = getSelectedLongitude();

    final url = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$latitude,$longitude",
    );

    final launched = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      showMessage("Unable to open Google Maps.");
    }
  }

  Map<dynamic, dynamic>? getSelectedVehicle() {
    if (selectedVehicleId == null) return null;

    final vehicle = vehicles[selectedVehicleId];

    if (vehicle == null) return null;
    if (vehicle is! Map) return null;

    return Map<dynamic, dynamic>.from(vehicle);
  }

  double getSelectedLatitude() {
    final vehicle = getSelectedVehicle();

    if (vehicle == null) {
      return defaultLatitude;
    }

    return double.tryParse(vehicle["latitude"]?.toString() ?? "") ??
        defaultLatitude;
  }

  double getSelectedLongitude() {
    final vehicle = getSelectedVehicle();

    if (vehicle == null) {
      return defaultLongitude;
    }

    return double.tryParse(vehicle["longitude"]?.toString() ?? "") ??
        defaultLongitude;
  }

  bool hasVehicleLocation() {
    final vehicle = getSelectedVehicle();

    if (vehicle == null) return false;

    final latitude = double.tryParse(vehicle["latitude"]?.toString() ?? "");
    final longitude = double.tryParse(vehicle["longitude"]?.toString() ?? "");

    return latitude != null && longitude != null;
  }

  String getVehicleText(String key) {
    final vehicle = getSelectedVehicle();

    if (vehicle == null) return "--";

    return vehicle[key]?.toString() ?? "--";
  }

  Color getStatusColor(String status) {
    final value = status.toUpperCase();

    if (value == "SAFE") {
      return Colors.green;
    }

    if (value == "WARNING") {
      return Colors.orange;
    }

    if (value == "DANGEROUS") {
      return Colors.redAccent;
    }

    return Colors.grey;
  }

  void showMessage(String message) {
    if (!mounted) return;

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
                  const Color(0xFF1E3A8A),
                  const Color(0xFF0F172A),
                ]
              : [
                  Colors.lightBlue,
                  Colors.blueAccent,
                ],
        ),
        borderRadius: BorderRadius.circular(28),
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
              Icons.location_on_rounded,
              color: Colors.white,
              size: 70,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Vehicle Location",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Save vehicle GPS location and open it in Google Maps",
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

  Widget buildVehicleSelector(bool isDarkMode) {
    if (vehicles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: getCardColor(isDarkMode),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          "No vehicle registered yet. Please register a vehicle first.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: getMainTextColor(isDarkMode),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final dropdownValue =
        vehicles.containsKey(selectedVehicleId) ? selectedVehicleId : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: getCardColor(isDarkMode),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: dropdownValue,
            decoration: InputDecoration(
              labelText: "Select Vehicle",
              prefixIcon: const Icon(Icons.directions_car_rounded),
              filled: true,
              fillColor:
                  isDarkMode ? const Color(0xFF0F172A) : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            dropdownColor: getCardColor(isDarkMode),
            style: TextStyle(
              color: getMainTextColor(isDarkMode),
              fontWeight: FontWeight.bold,
            ),
            items: vehicles.entries.map((entry) {
              final vehicle = entry.value is Map
                  ? Map<dynamic, dynamic>.from(entry.value as Map)
                  : <dynamic, dynamic>{};

              final plate = vehicle["plateNumber"]?.toString() ?? "Vehicle";
              final brand = vehicle["brand"]?.toString() ?? "";
              final model = vehicle["model"]?.toString() ?? "";

              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(
                  "$plate - $brand $model",
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedVehicleId = value;
              });
              _updateMapCamera();
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: isSavingLocation ? null : saveCurrentLocation,
              icon: isSavingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.my_location_rounded),
              label: Text(
                isSavingLocation
                    ? "Saving Location..."
                    : "Save Current Location",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue,
                foregroundColor: Colors.white,
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

  Widget buildMapCard(bool isDarkMode) {
    final hasLocation = hasVehicleLocation();
    final latitude = getSelectedLatitude();
    final longitude = getSelectedLongitude();

    return Container(
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
          Row(
            children: [
              const Icon(
                Icons.map_rounded,
                color: Colors.lightBlue,
              ),
              const SizedBox(width: 8),
              Text(
                "Flood Risk Map",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: getMainTextColor(isDarkMode),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 250,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.lightBlue.withOpacity(0.35),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: hasLocation
                  ? GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: LatLng(latitude, longitude),
                        zoom: 15.0,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId("vehicle_position"),
                          position: LatLng(latitude, longitude),
                          infoWindow: InfoWindow(
                            title: getVehicleText("plateNumber"),
                            snippet: "Flood Status: ${getVehicleText("currentStatus")}",
                          ),
                        ),
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.location_off_rounded,
                            color: Colors.grey,
                            size: 44,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "No GPS location saved yet",
                            style: TextStyle(
                              color: getMainTextColor(isDarkMode),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              "Press Save Current Location first to store your vehicle position.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: getSubTextColor(isDarkMode),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          if (hasLocation) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                "Latitude: $latitude  |  Longitude: $longitude",
                style: TextStyle(
                  color: getSubTextColor(isDarkMode),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: hasLocation ? openGoogleMaps : null,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text("Open in Google Maps"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade500,
                disabledForegroundColor: Colors.white70,
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

  Widget buildVehicleInfo(bool isDarkMode) {
    final status = getVehicleText("currentStatus");
    final statusColor = getStatusColor(status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: getCardColor(isDarkMode),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          infoRow(
            icon: Icons.pin_rounded,
            title: "Plate Number",
            value: getVehicleText("plateNumber"),
            isDarkMode: isDarkMode,
          ),
          infoRow(
            icon: Icons.location_on_rounded,
            title: "Parking Location",
            value: getVehicleText("parkingLocation"),
            isDarkMode: isDarkMode,
          ),
          infoRow(
            icon: Icons.my_location_rounded,
            title: "Latitude",
            value: hasVehicleLocation()
                ? getSelectedLatitude().toString()
                : "--",
            isDarkMode: isDarkMode,
          ),
          infoRow(
            icon: Icons.my_location_rounded,
            title: "Longitude",
            value: hasVehicleLocation()
                ? getSelectedLongitude().toString()
                : "--",
            isDarkMode: isDarkMode,
          ),
          infoRow(
            icon: Icons.access_time_rounded,
            title: "Location Updated",
            value: getVehicleText("locationUpdatedAt"),
            isDarkMode: isDarkMode,
          ),
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Text(
                "Flood Risk: ",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: getSubTextColor(isDarkMode),
                ),
              ),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            icon,
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

  Widget buildEmptyInfo(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: getCardColor(isDarkMode),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.directions_car_filled_rounded,
            size: 50,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 10),
          Text(
            "No vehicle data available",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: getMainTextColor(isDarkMode),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Please register your vehicle first before saving the location.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: getSubTextColor(isDarkMode),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: getBackgroundColor(isDarkMode),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: getBackgroundColor(isDarkMode),
        foregroundColor: getMainTextColor(isDarkMode),
        title: const Text("Vehicle Location"),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              loadVehicles();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                buildHeader(isDarkMode),
                const SizedBox(height: 18),
                buildVehicleSelector(isDarkMode),
                const SizedBox(height: 18),
                buildMapCard(isDarkMode),
                const SizedBox(height: 18),
                vehicles.isEmpty
                    ? buildEmptyInfo(isDarkMode)
                    : buildVehicleInfo(isDarkMode),
              ],
            ),
    );
  }
}