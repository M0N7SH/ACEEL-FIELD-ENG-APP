import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:field_accel/snapped_route.dart';

class FlutterMapPage extends StatefulWidget {
  final String tripId;
  final String? userId;

  const FlutterMapPage({super.key, required this.tripId, required this.userId});

  @override
  State<FlutterMapPage> createState() => _FlutterMapPageState();
}

class _FlutterMapPageState extends State<FlutterMapPage> {
  List<LatLng> coordinates = [];
  List<Marker> allMarkers = [];
  late final MapController _mapController;
  LatLng _currentCenter = const LatLng(13.05896494788499, 80.24253644486387);
  double _zoom = 15;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    loadTripData();
  }

  Future<void> loadTripData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.userId == null || widget.userId!.isEmpty) {
      print("User not signed in or userId is null.");
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('tracking')
        .doc(widget.userId)
        .collection('trips')
        .doc(widget.tripId)
        .get();

    final data = doc.data();
    if (data == null) return;

    final coordList = data['coord-ts'] ?? [];
    final stops = data['stops'] ?? [];

    List<LatLng> rawCoords = coordList.map<LatLng>((entry) {
      return LatLng(entry['latitude'] ?? 13.05896494788499, entry['longitude'] ?? 80.24253644486387);
    }).toList();

    coordinates = await getSnappedRoute(rawCoords); // snapped route

    // Start marker
    if (coordinates.isNotEmpty) {
      allMarkers.add(Marker(
        width: 40,
        height: 40,
        point: coordinates.first,
        child: const Icon(Icons.location_on, color: Colors.green),
      ));
    }

    // End marker
    if (coordinates.length > 1) {
      allMarkers.add(Marker(
        width: 40,
        height: 40,
        point: coordinates.last,
        child: const Icon(Icons.location_on, color: Colors.red),
      ));
    }

    // Stop markers with reverse geocoding
    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final lat = stop['latitude'];
      final lng = stop['longitude'];
      final duration = stop['duration_minutes'];

      String address = "Loading...";
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          address =
          "${place.name ?? ''}, ${place.street ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}";
        }
      } catch (e) {
        address = "Unknown location";
        print("Geocoding failed: $e");
      }

      allMarkers.add(Marker(
        width: 40,
        height: 40,
        point: LatLng(lat, lng),
        child: GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text("Stop ${i + 1}"),
                content: Text("📍 $address\n🕒 $duration min"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close"),
                  )
                ],
              ),
            );
          },
          child: const Icon(Icons.pause_circle_filled, color: Colors.orange),
        ),
      ));
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Trip: ${widget.tripId}")),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: coordinates.isNotEmpty
                  ? coordinates.first
                  : _currentCenter,
              minZoom: 14,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.field-accel',
              ),
              if (coordinates.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: coordinates,
                      color: Colors.blue,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              // ✅ ADDED: MarkerLayer to show all markers
              MarkerLayer(
                markers: allMarkers,
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            right: 10,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "zoom-in",
                  mini: true,
                  onPressed: () {
                    setState(() {
                      _zoom += 1;
                      _mapController.move(_currentCenter, _zoom);
                    });
                  },
                  child: const Icon(Icons.zoom_in),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "zoom-out",
                  mini: true,
                  onPressed: () {
                    setState(() {
                      _zoom -= 1;
                      _mapController.move(_currentCenter, _zoom);
                    });
                  },
                  child: const Icon(Icons.zoom_out),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
