import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FloodRiskMapPage extends StatefulWidget {
  const FloodRiskMapPage({super.key});

  @override
  State<FloodRiskMapPage> createState() => _FloodRiskMapPageState();
}

class _FloodRiskMapPageState extends State<FloodRiskMapPage> {
  final String databaseURL =
      "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app";

  GoogleMapController? _mapController;
  StreamSubscription? _subscription;

  String liveStatus = "SAFE";
  double liveHeight = 0.0;
  bool isLoading = true;

  Map<String, dynamic>? selectedStation;

  FirebaseDatabase get database {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: databaseURL,
    );
  }

  @override
  void initState() {
    super.initState();
    _startLiveSensorSubscription();
    // Default to main sensor details initially
    _selectMainSensor();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startLiveSensorSubscription() {
    try {
      final ref = database.ref("FloodMonitoring");
      _subscription = ref.onValue.listen(
        (event) {
          if (event.snapshot.exists && event.snapshot.value != null) {
            final data =
                Map<dynamic, dynamic>.from(event.snapshot.value as Map);
            if (!mounted) return;
            setState(() {
              liveStatus =
                  data["flood_status"]?.toString().toUpperCase() ?? "SAFE";
              liveHeight = double.tryParse(
                    data["water_height_cm"]?.toString() ?? "0.0",
                  ) ??
                  0.0;
              isLoading = false;

              // Update panel dynamically if main sensor is selected
              if (selectedStation != null &&
                  selectedStation!["isLive"] == true) {
                selectedStation = _getMainSensorMap();
              }
            });
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to read live sensor: $e")),
            );
          }
        },
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _selectMainSensor() {
    setState(() {
      selectedStation = _getMainSensorMap();
    });
  }

  Map<String, dynamic> _getMainSensorMap() {
    return {
      "name": "UTM Lake (Main Station)",
      "location": "Skudai, Johor (UTM Campus)",
      "status": liveStatus,
      "height":
          "${(liveHeight / 100.0).toStringAsFixed(2)}m (${liveHeight.toStringAsFixed(0)} cm)",
      "isLive": true,
    };
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  Color getStatusColor(String status) {
    final val = status.toUpperCase();
    if (val == "SAFE") return Colors.green;
    if (val == "WARNING") return Colors.orange;
    if (val == "DANGEROUS") return Colors.redAccent;
    return Colors.grey;
  }

  Set<Marker> _getMarkers() {
    double mainHue = BitmapDescriptor.hueGreen;
    if (liveStatus == "DANGEROUS") {
      mainHue = BitmapDescriptor.hueRed;
    } else if (liveStatus == "WARNING") {
      mainHue = BitmapDescriptor.hueOrange;
    }

    return {
      Marker(
        markerId: const MarkerId("utm_lake"),
        position: const LatLng(1.5586, 103.6375),
        icon: BitmapDescriptor.defaultMarkerWithHue(mainHue),
        onTap: () {
          setState(() {
            selectedStation = _getMainSensorMap();
          });
        },
      ),
      Marker(
        markerId: const MarkerId("tebrau_river"),
        position: const LatLng(1.4920, 103.7620),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        onTap: () {
          setState(() {
            selectedStation = {
              "name": "Tebrau River Station",
              "location": "Johor Bahru",
              "status": "DANGEROUS",
              "height": "2.40m (240 cm)",
              "isLive": false,
            };
          });
        },
      ),
      Marker(
        markerId: const MarkerId("skudai_river"),
        position: const LatLng(1.5300, 103.6600),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        onTap: () {
          setState(() {
            selectedStation = {
              "name": "Skudai River Station",
              "location": "Skudai, Johor",
              "status": "WARNING",
              "height": "1.85m (185 cm)",
              "isLive": false,
            };
          });
        },
      ),
      Marker(
        markerId: const MarkerId("segget_river"),
        position: const LatLng(1.4580, 103.7640),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        onTap: () {
          setState(() {
            selectedStation = {
              "name": "Segget River Station",
              "location": "Johor Bahru City Center",
              "status": "SAFE",
              "height": "0.45m (45 cm)",
              "isLive": false,
            };
          });
        },
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final markers = _getMarkers();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Flood Risk Map"),
        backgroundColor:
            isDarkMode ? const Color(0xFF0F172A) : Colors.lightBlue.shade50,
        foregroundColor: isDarkMode ? Colors.white : Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Google Map
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(1.5150, 103.7100), // Mid-point of Johor area
                    zoom: 12.0,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  markers: markers,
                ),

                // Top Floating Legend Info
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF1E293B).withOpacity(0.9)
                          : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.lightBlue.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        legendItem(Colors.green, "Safe"),
                        legendItem(Colors.orange, "Warning"),
                        legendItem(Colors.redAccent, "Dangerous"),
                      ],
                    ),
                  ),
                ),

                // Bottom Floating Station Detail Card
                if (selectedStation != null)
                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF1E293B)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: getStatusColor(selectedStation!["status"])
                              .withOpacity(0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withOpacity(isDarkMode ? 0.35 : 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Name and Close
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  selectedStation!["name"],
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close_rounded),
                                color: isDarkMode ? Colors.white70 : Colors.black54,
                                onPressed: () {
                                  setState(() {
                                    selectedStation = null;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Location Description
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 16,
                                color: isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                selectedStation!["location"],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDarkMode
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Divider(
                            color: isDarkMode
                                ? Colors.grey.shade700
                                : Colors.grey.shade200,
                          ),
                          const SizedBox(height: 10),
                          // Stats row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Water Level",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedStation!["height"],
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: getStatusColor(
                                        selectedStation!["status"],
                                      ).withOpacity(0.16),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: getStatusColor(
                                          selectedStation!["status"],
                                        ).withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      selectedStation!["status"],
                                      style: TextStyle(
                                        color: getStatusColor(
                                          selectedStation!["status"],
                                        ),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selectedStation!["isLive"]
                                          ? Colors.green.withOpacity(0.12)
                                          : Colors.grey.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      selectedStation!["isLive"]
                                          ? "LIVE DATA"
                                          : "SIMULATED",
                                      style: TextStyle(
                                        color: selectedStation!["isLive"]
                                            ? Colors.green
                                            : Colors.grey.shade500,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 9,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
