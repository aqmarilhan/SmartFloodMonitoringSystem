import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Vehicle Management & Location Screen
/// Consolidates vehicle registration and location control into one module.
class VehicleLocationPage extends StatefulWidget {
  const VehicleLocationPage({super.key});

  @override
  State<VehicleLocationPage> createState() => _VehicleLocationPageState();
}

class _VehicleLocationPageState extends State<VehicleLocationPage> {
  // Firebase Realtime Database URL
  final String databaseURL =
      "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app";

  // State Management Flags
  bool isLoading = true;
  bool isSavingLocation = false;
  bool isSearchingAddress = false;
  bool isSavingVehicle = false;
  bool showRegisterForm = false; // Controls registration form expansion

  // Data Stores
  Map<String, dynamic> vehicles = {};
  String? selectedVehicleId;

  // Text Editing Controllers for Forms
  final addressController = TextEditingController();
  final plateController = TextEditingController();
  final brandController = TextEditingController();
  final modelController = TextEditingController();
  final colorController = TextEditingController();
  final parkingLocationController = TextEditingController();

  // Default Map Coordinates (Johor/UTM region)
  final double defaultLatitude = 1.5586;
  final double defaultLongitude = 103.6375;

  // Google Maps Controllers
  GoogleMapController? _mapController;
  LatLng? tappedLatLng; // Stores user tapped location on map
  LatLng? initialMapCenter;

  // Getter for Firebase Database instance
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
    _fetchInitialMapCenter();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    addressController.dispose();
    plateController.dispose();
    brandController.dispose();
    modelController.dispose();
    colorController.dispose();
    parkingLocationController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // MAP CONTROLS & CAMERA METHODS
  // ===========================================================================

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Updates map camera focus based on selected vehicle or user pins
  void _updateMapCamera() {
    if (_mapController != null) {
      LatLng target;
      if (tappedLatLng != null) {
        target = tappedLatLng!;
      } else if (hasVehicleLocation()) {
        target = LatLng(getSelectedLatitude(), getSelectedLongitude());
      } else if (initialMapCenter != null) {
        target = initialMapCenter!;
      } else {
        target = LatLng(defaultLatitude, defaultLongitude);
      }
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(target, 15.0),
      );
    }
  }

  /// Obtains initial coordinates from the phone's GPS hardware
  Future<void> _fetchInitialMapCenter() async {
    try {
      final position = await getCurrentPosition();
      if (position != null && mounted) {
        setState(() {
          initialMapCenter = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      debugPrint("Error fetching map center: $e");
    }
  }

  // ===========================================================================
  // DATABASE OPERATIONS (FIREBASE RTDB)
  // ===========================================================================

  /// Loads vehicles registered under the current logged-in user
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
      final snapshot = await ref.get().timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (snapshot.exists && snapshot.value != null) {
        final rawData = Map<dynamic, dynamic>.from(snapshot.value as Map);
        final convertedData = rawData.map((k, v) => MapEntry(k.toString(), v));

        setState(() {
          vehicles = convertedData;
          selectedVehicleId =
              convertedData.isNotEmpty ? convertedData.keys.first : null;
          isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) => _updateMapCamera());
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

  /// Adds a new vehicle to the Firebase database under the user's account
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
      isSavingVehicle = true;
    });

    try {
      String ownerUsername = "Unknown User";
      final userSnapshot = await database
          .ref("Users/${user.uid}")
          .get()
          .timeout(const Duration(seconds: 10));

      if (userSnapshot.exists && userSnapshot.value != null) {
        final userData = Map<dynamic, dynamic>.from(userSnapshot.value as Map);
        ownerUsername = userData["username"]?.toString() ?? "Unknown User";
      }

      final ref = database.ref("Vehicles/${user.uid}");
      final existingSnapshot =
          await ref.get().timeout(const Duration(seconds: 10));

      bool plateExists = false;
      if (existingSnapshot.exists && existingSnapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(existingSnapshot.value as Map);
        data.forEach((key, value) {
          final vehicle = Map<dynamic, dynamic>.from(value);
          final existingPlate =
              vehicle["plateNumber"]?.toString().toUpperCase() ?? "";
          if (existingPlate == plateNumber) {
            plateExists = true;
          }
        });
      }

      if (plateExists) {
        if (!mounted) return;
        setState(() {
          isSavingVehicle = false;
        });
        showMessage("This vehicle plate number is already registered.");
        return;
      }

      final newVehicleRef = ref.push();
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

      await loadVehicles();

      if (!mounted) return;
      setState(() {
        isSavingVehicle = false;
        showRegisterForm = false; // Auto collapse registration form
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
        isSavingVehicle = false;
      });
      showMessage("Failed to register vehicle: $e");
    }
  }

  /// Deletes a vehicle node from the Firebase Database
  Future<void> deleteVehicle({
    required String vehicleId,
    required String plateNumber,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await database.ref("Vehicles/${user!.uid}/$vehicleId").remove();
      await loadVehicles();
      showMessage("$plateNumber deleted successfully.");
    } catch (e) {
      showMessage("Failed to delete vehicle: $e");
    }
  }

  /// Updates the selected vehicle coordinates using GPS hardware
  Future<void> saveCurrentLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || selectedVehicleId == null) {
      showMessage(user == null ? "User not logged in." : "Please register a vehicle first.");
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

      String parkingLocation = "Current GPS Location";
      final address = await _reverseGeocode(position.latitude, position.longitude);
      if (address != null && address.isNotEmpty) {
        parkingLocation = address;
      }

      final ref = database.ref("Vehicles/${user.uid}/$selectedVehicleId");
      await ref.update({
        "latitude": position.latitude,
        "longitude": position.longitude,
        "parkingLocation": parkingLocation,
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

  /// Updates selected vehicle coordinates using the pinned map marker
  Future<void> saveTappedLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || selectedVehicleId == null || tappedLatLng == null) {
      showMessage(tappedLatLng == null ? "No location selected on map." : "Please register/select a vehicle first.");
      return;
    }

    setState(() {
      isSavingLocation = true;
    });

    try {
      String parkingLocation = "Custom Pin Location";
      final address = await _reverseGeocode(tappedLatLng!.latitude, tappedLatLng!.longitude);
      if (address != null && address.isNotEmpty) {
        parkingLocation = address;
      }

      final ref = database.ref("Vehicles/${user.uid}/$selectedVehicleId");
      await ref.update({
        "latitude": tappedLatLng!.latitude,
        "longitude": tappedLatLng!.longitude,
        "parkingLocation": parkingLocation,
        "locationUpdatedAt": DateTime.now().toString(),
        "locationUpdatedAtEpoch": DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });

      await loadVehicles();

      if (!mounted) return;
      setState(() {
        tappedLatLng = null;
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

  // ===========================================================================
  // PHYSICAL LOCATION & API GEOCULATION
  // ===========================================================================

  /// Interacts with geolocator library to request permission and poll coordinates
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
      showMessage("Location permission permanently denied. Please enable it in settings.");
      return null;
    }

    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .timeout(const Duration(seconds: 15));
  }

  /// Geocoding: Translates text address to Latitude/Longitude (OSM Nominatim API)
  Future<LatLng?> _geocodeAddress(String address) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse(
          "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&limit=1");
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, "SmartFloodEarlyWarningApp/1.0");
      final response = await request.close();
      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        final json = jsonDecode(content);
        if (json is List && json.isNotEmpty) {
          final lat = double.tryParse(json[0]["lat"]?.toString() ?? "");
          final lon = double.tryParse(json[0]["lon"]?.toString() ?? "");
          if (lat != null && lon != null) {
            return LatLng(lat, lon);
          }
        }
      }
    } catch (e) {
      debugPrint("Geocoding error: $e");
    }
    return null;
  }

  /// Reverse Geocoding: Translates Latitude/Longitude to text address
  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse(
          "https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json");
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, "SmartFloodEarlyWarningApp/1.0");
      final response = await request.close();
      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        final json = jsonDecode(content);
        if (json is Map && json.containsKey("display_name")) {
          return json["display_name"]?.toString();
        }
      }
    } catch (e) {
      debugPrint("Reverse geocoding error: $e");
    }
    return null;
  }

  /// Actions search bar input geocode coordinates
  Future<void> searchAndSetAddress() async {
    final address = addressController.text.trim();
    if (address.isEmpty) {
      showMessage("Please enter an address first.");
      return;
    }

    setState(() {
      isSearchingAddress = true;
    });

    final latLng = await _geocodeAddress(address);

    if (!mounted) return;
    setState(() {
      isSearchingAddress = false;
    });

    if (latLng != null) {
      setState(() {
        tappedLatLng = latLng;
      });
      _updateMapCamera();
      showMessage("Location found! Tap 'Save Selected Location' to confirm.");
    } else {
      showMessage("Address not found. Please try a different search.");
    }
  }

  /// Launches third party Google Maps navigation with selected coordinates
  Future<void> openGoogleMaps() async {
    if (!hasVehicleLocation()) {
      showMessage("Please save vehicle location first.");
      return;
    }

    final url = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=${getSelectedLatitude()},${getSelectedLongitude()}",
    );

    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched) {
      showMessage("Unable to open Google Maps.");
    }
  }

  // ===========================================================================
  // SELECTORS & CONTEXT UTILITIES
  // ===========================================================================

  Map<dynamic, dynamic>? getSelectedVehicle() {
    if (selectedVehicleId == null) return null;
    final vehicle = vehicles[selectedVehicleId];
    return vehicle is Map ? Map<dynamic, dynamic>.from(vehicle) : null;
  }

  double getSelectedLatitude() {
    final vehicle = getSelectedVehicle();
    return double.tryParse(vehicle?["latitude"]?.toString() ?? "") ?? defaultLatitude;
  }

  double getSelectedLongitude() {
    final vehicle = getSelectedVehicle();
    return double.tryParse(vehicle?["longitude"]?.toString() ?? "") ?? defaultLongitude;
  }

  bool hasVehicleLocation() {
    final vehicle = getSelectedVehicle();
    if (vehicle == null) return false;
    final lat = double.tryParse(vehicle["latitude"]?.toString() ?? "");
    final lon = double.tryParse(vehicle["longitude"]?.toString() ?? "");
    return lat != null && lon != null;
  }

  String getVehicleText(String key) {
    return getSelectedVehicle()?[key]?.toString() ?? "--";
  }

  Color getStatusColor(String status) {
    final value = status.toUpperCase();
    if (value == "SAFE") return Colors.green;
    if (value == "WARNING") return Colors.orange;
    if (value == "DANGEROUS") return Colors.redAccent;
    return Colors.grey;
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Dynamic Theme Palette getters
  Color getBackgroundColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF0F172A) : Colors.lightBlue.shade50;

  Color getCardColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF1E293B) : Colors.white;

  Color getMainTextColor(bool isDarkMode) =>
      isDarkMode ? Colors.white : Colors.black87;

  Color getSubTextColor(bool isDarkMode) =>
      isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700;

  // ===========================================================================
  // UI WIDGET COMPOSITIONS
  // ===========================================================================

  Widget buildHeader(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [const Color(0xFF1E3A8A), const Color(0xFF0F172A)]
              : [Colors.lightBlue, Colors.blueAccent],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 70),
          ),
          const SizedBox(height: 16),
          const Text(
            "Vehicle Management",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            "Register vehicles, manage details, and track GPS locations on the map.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.4, color: Colors.white.withOpacity(0.88)),
          ),
        ],
      ),
    );
  }

  Widget buildVehicleSelector(bool isDarkMode) {
    if (vehicles.isEmpty) return const SizedBox.shrink();

    final dropdownValue = vehicles.containsKey(selectedVehicleId) ? selectedVehicleId : null;

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
              fillColor: isDarkMode ? const Color(0xFF0F172A) : Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
            ),
            dropdownColor: getCardColor(isDarkMode),
            style: TextStyle(color: getMainTextColor(isDarkMode), fontWeight: FontWeight.bold),
            items: vehicles.entries.map((entry) {
              final vehicle = entry.value is Map ? Map.from(entry.value) : {};
              final plate = vehicle["plateNumber"]?.toString() ?? "Vehicle";
              final brand = vehicle["brand"]?.toString() ?? "";
              final model = vehicle["model"]?.toString() ?? "";
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text("$plate - $brand $model", overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedVehicleId = value;
                tappedLatLng = null;
              });
              _updateMapCamera();
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: addressController,
                  style: TextStyle(color: getMainTextColor(isDarkMode)),
                  decoration: InputDecoration(
                    labelText: "Set location by address",
                    hintText: "Type an address...",
                    hintStyle: TextStyle(color: getSubTextColor(isDarkMode).withOpacity(0.6)),
                    prefixIcon: const Icon(Icons.location_on_rounded),
                    filled: true,
                    fillColor: isDarkMode ? const Color(0xFF0F172A) : Colors.grey.shade100,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: isDarkMode ? const Color(0xFF06B6D4) : const Color(0xFF0284C7),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: isSearchingAddress ? null : searchAndSetAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: isSearchingAddress
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLocationSaveActions(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildLocationSaveActions(bool isDarkMode) {
    if (tappedLatLng != null) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: isSavingLocation ? null : saveTappedLocation,
              icon: isSavingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: const Text("Save Selected Location"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  tappedLatLng = null;
                });
                _updateMapCamera();
              },
              icon: const Icon(Icons.cancel_rounded),
              label: const Text("Clear Selected Location"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: isSavingLocation ? null : saveCurrentLocation,
        icon: isSavingLocation
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.my_location_rounded),
        label: Text(isSavingLocation ? "Saving Location..." : "Save Current Location"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.lightBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  Widget buildMapCard(bool isDarkMode) {
    final hasLocation = hasVehicleLocation();
    final latitude = getSelectedLatitude();
    final longitude = getSelectedLongitude();
    final mapCenter = tappedLatLng ?? (hasLocation ? LatLng(latitude, longitude) : (initialMapCenter ?? LatLng(defaultLatitude, defaultLongitude)));

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
              const Icon(Icons.map_rounded, color: Colors.lightBlue),
              const SizedBox(width: 8),
              Text(
                "Flood Risk Map",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: getMainTextColor(isDarkMode)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 250,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.lightBlue.withOpacity(0.35)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(target: mapCenter, zoom: 15.0),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                onTap: (latLng) {
                  setState(() {
                    tappedLatLng = latLng;
                  });
                },
                markers: {
                  if (tappedLatLng != null)
                    Marker(
                      markerId: const MarkerId("tapped_position"),
                      position: tappedLatLng!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      infoWindow: const InfoWindow(
                        title: "Selected Location",
                        snippet: "Tap Save Selected Pin Location to confirm",
                      ),
                    )
                  else if (hasLocation)
                    Marker(
                      markerId: const MarkerId("vehicle_position"),
                      position: LatLng(latitude, longitude),
                      infoWindow: InfoWindow(
                        title: getVehicleText("plateNumber"),
                        snippet: "Flood Status: ${getVehicleText("currentStatus")}",
                      ),
                    ),
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              tappedLatLng != null
                  ? "Selected Pin: ${tappedLatLng!.latitude.toStringAsFixed(6)}, ${tappedLatLng!.longitude.toStringAsFixed(6)}"
                  : "Latitude: ${latitude.toStringAsFixed(6)}  |  Longitude: ${longitude.toStringAsFixed(6)}",
              style: TextStyle(
                color: tappedLatLng != null ? Colors.green.shade600 : getSubTextColor(isDarkMode),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
          _infoRow(icon: Icons.pin_rounded, title: "Plate Number", value: getVehicleText("plateNumber"), isDarkMode: isDarkMode),
          _infoRow(icon: Icons.location_on_rounded, title: "Parking Location", value: getVehicleText("parkingLocation"), isDarkMode: isDarkMode),
          _infoRow(icon: Icons.my_location_rounded, title: "Latitude", value: hasVehicleLocation() ? getSelectedLatitude().toString() : "--", isDarkMode: isDarkMode),
          _infoRow(icon: Icons.my_location_rounded, title: "Longitude", value: hasVehicleLocation() ? getSelectedLongitude().toString() : "--", isDarkMode: isDarkMode),
          _infoRow(icon: Icons.access_time_rounded, title: "Location Updated", value: getVehicleText("locationUpdatedAt"), isDarkMode: isDarkMode),
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: statusColor),
              const SizedBox(width: 8),
              Text(
                "Flood Risk: ",
                style: TextStyle(fontWeight: FontWeight.bold, color: getSubTextColor(isDarkMode)),
              ),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow({required IconData icon, required String title, required String value, required bool isDarkMode}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.lightBlue),
          const SizedBox(width: 8),
          Text(
            "$title: ",
            style: TextStyle(fontWeight: FontWeight.bold, color: getSubTextColor(isDarkMode)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: getMainTextColor(isDarkMode)),
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
          Icon(Icons.directions_car_filled_rounded, size: 50, color: Colors.grey.shade500),
          const SizedBox(height: 10),
          Text(
            "No vehicle data available",
            textAlign: TextAlign.center,
            style: TextStyle(color: getMainTextColor(isDarkMode), fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            "Please register your vehicle first before saving the location.",
            textAlign: TextAlign.center,
            style: TextStyle(color: getSubTextColor(isDarkMode)),
          ),
        ],
      ),
    );
  }

  Widget buildRegisterForm(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: getCardColor(isDarkMode),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Register New Vehicle",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: getMainTextColor(isDarkMode)),
          ),
          const SizedBox(height: 16),
          _buildFormTextField(controller: plateController, label: "Plate Number", hint: "e.g., JQW1234", icon: Icons.pin_rounded, isDarkMode: isDarkMode, textCapitalization: TextCapitalization.characters),
          _buildFormTextField(controller: brandController, label: "Brand", hint: "e.g., Proton, Toyota", icon: Icons.branding_watermark_rounded, isDarkMode: isDarkMode),
          _buildFormTextField(controller: modelController, label: "Model", hint: "e.g., Saga, Vios", icon: Icons.model_training_rounded, isDarkMode: isDarkMode),
          _buildFormTextField(controller: colorController, label: "Color", hint: "e.g., Black, White", icon: Icons.color_lens_rounded, isDarkMode: isDarkMode),
          _buildFormTextField(controller: parkingLocationController, label: "Default Parking Location", hint: "e.g., Block A, Lot 45", icon: Icons.local_parking_rounded, isDarkMode: isDarkMode),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isSavingVehicle ? null : saveVehicle,
              icon: isSavingVehicle
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_circle_rounded),
              label: const Text("Register Vehicle"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormTextField({
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
        style: TextStyle(color: getMainTextColor(isDarkMode)),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: getSubTextColor(isDarkMode).withOpacity(0.6)),
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: isDarkMode ? const Color(0xFF0F172A) : Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
          ),
        ),
      ),
    );
  }

  Widget buildRegisteredVehiclesList(bool isDarkMode) {
    if (vehicles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
          child: Text(
            "Registered Vehicles (${vehicles.length})",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: getMainTextColor(isDarkMode)),
          ),
        ),
        ...vehicles.entries.map((entry) {
          final vehicle = entry.value is Map ? Map.from(entry.value) : {};
          final plate = vehicle["plateNumber"]?.toString() ?? "Vehicle";
          final brand = vehicle["brand"]?.toString() ?? "";
          final model = vehicle["model"]?.toString() ?? "";
          final color = vehicle["color"]?.toString() ?? "";
          final parkLoc = vehicle["parkingLocation"]?.toString() ?? "";

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: getCardColor(isDarkMode),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF06B6D4).withOpacity(0.15) : const Color(0xFF0284C7).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_car_filled_rounded,
                    color: isDarkMode ? const Color(0xFF06B6D4) : const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plate,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: getMainTextColor(isDarkMode)),
                      ),
                      const SizedBox(height: 4),
                      Text("$brand $model • $color", style: TextStyle(color: getSubTextColor(isDarkMode))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 16, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              parkLoc,
                              style: TextStyle(fontSize: 13, color: getSubTextColor(isDarkMode)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => showDeleteDialog(vehicleId: entry.key, plateNumber: plate),
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.redAccent,
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  void showDeleteDialog({required String vehicleId, required String plateNumber}) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Delete Vehicle"),
          content: Text("Delete vehicle $plateNumber?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await deleteVehicle(vehicleId: vehicleId, plateNumber: plateNumber);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // MAIN WIDGET BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: getBackgroundColor(isDarkMode),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: getBackgroundColor(isDarkMode),
        foregroundColor: getMainTextColor(isDarkMode),
        title: const Text("Vehicle Management"),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadVehicles,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                children: [
                  buildHeader(isDarkMode),
                  const SizedBox(height: 18),
                  
                  // Vehicles List Card (shows if not empty)
                  buildRegisteredVehiclesList(isDarkMode),
                  const SizedBox(height: 12),

                  // Toggle Registration Form Button
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          showRegisterForm = !showRegisterForm;
                        });
                      },
                      icon: Icon(showRegisterForm
                          ? Icons.remove_circle_outline_rounded
                          : Icons.add_circle_outline_rounded),
                      label: Text(showRegisterForm ? "Hide Registration Form" : "Register New Vehicle"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDarkMode ? const Color(0xFF06B6D4) : const Color(0xFF0284C7),
                        side: BorderSide(
                          color: isDarkMode ? const Color(0xFF06B6D4) : const Color(0xFF0284C7),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Registration Form Section (shown if toggled or if list is empty)
                  if (showRegisterForm || vehicles.isEmpty) ...[
                    buildRegisterForm(isDarkMode),
                    const SizedBox(height: 18),
                  ],

                  // Divider and Location Controls (shown only when vehicles exist)
                  if (vehicles.isNotEmpty) ...[
                    const Divider(height: 32, thickness: 1),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
                      child: Text(
                        "Location Control & Tracking",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: getMainTextColor(isDarkMode)),
                      ),
                    ),
                    buildVehicleSelector(isDarkMode),
                    const SizedBox(height: 18),
                    buildMapCard(isDarkMode),
                    const SizedBox(height: 18),
                    buildVehicleInfo(isDarkMode),
                  ] else ...[
                    buildEmptyInfo(isDarkMode),
                  ],
                ],
              ),
            ),
    );
  }
}