import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io';
import 'dart:convert';

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
  bool isSearchingAddress = false;

  Map<String, dynamic> vehicles = {};
  String? selectedVehicleId;

  final addressController = TextEditingController();

  final double defaultLatitude = 1.5586;
  final double defaultLongitude = 103.6375;

  GoogleMapController? _mapController;
  LatLng? tappedLatLng;
  LatLng? initialMapCenter;

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
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

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
        CameraUpdate.newLatLngZoom(
          target,
          15.0,
        ),
      );
    }
  }

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

  Future<LatLng?> _geocodeAddress(String address) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse("https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&limit=1");
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

  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse("https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json");
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

  Future<void> saveTappedLocation() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage("User not logged in.");
      return;
    }

    if (selectedVehicleId == null) {
      showMessage("Please register a vehicle first.");
      return;
    }

    if (tappedLatLng == null) {
      showMessage("No location selected on map.");
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
                tappedLatLng = null; // Clear custom pin on change
              });
              _updateMapCamera();
            },
          ),
          const SizedBox(height: 16),
          // Set Location by Address Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: addressController,
                  style: TextStyle(
                    color: getMainTextColor(isDarkMode),
                  ),
                  decoration: InputDecoration(
                    labelText: "Set location by address",
                    hintText: "Type an address...",
                    hintStyle: TextStyle(
                      color: getSubTextColor(isDarkMode).withOpacity(0.6),
                    ),
                    prefixIcon: const Icon(Icons.location_on_rounded),
                    filled: true,
                    fillColor: isDarkMode
                        ? const Color(0xFF0F172A)
                        : Colors.grey.shade100,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        width: 1,
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: isSearchingAddress
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (tappedLatLng != null) ...[
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: isSavingLocation ? null : saveTappedLocation,
                icon: isSavingLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: const Text("Save Selected Location"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ] else ...[
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
        ],
      ),
    );
  }

  Widget buildMapCard(bool isDarkMode) {
    final hasLocation = hasVehicleLocation();
    final latitude = getSelectedLatitude();
    final longitude = getSelectedLongitude();

    // Determine the map center position
    LatLng mapCenter;
    if (tappedLatLng != null) {
      mapCenter = tappedLatLng!;
    } else if (hasLocation) {
      mapCenter = LatLng(latitude, longitude);
    } else {
      mapCenter = initialMapCenter ?? LatLng(defaultLatitude, defaultLongitude);
    }

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
              child: GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: mapCenter,
                  zoom: 15.0,
                ),
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
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed,
                      ),
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
                        snippet:
                            "Flood Status: ${getVehicleText("currentStatus")}",
                      ),
                    ),
                },
              ),
            ),
          ),
          if (tappedLatLng != null) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                "Selected Pin: ${tappedLatLng!.latitude.toStringAsFixed(6)}, ${tappedLatLng!.longitude.toStringAsFixed(6)}",
                style: TextStyle(
                  color: Colors.green.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ] else if (hasLocation) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                "Latitude: ${latitude.toStringAsFixed(6)}  |  Longitude: ${longitude.toStringAsFixed(6)}",
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
          : RefreshIndicator(
              onRefresh: loadVehicles,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
          ),
    );
  }
}