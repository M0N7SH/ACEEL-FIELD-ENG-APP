import 'dart:async';
import 'dart:math';
import 'package:field_accel/pages/google_map.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import '../models/location_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // for formatting date
import 'package:firebase_auth/firebase_auth.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool isTracking = false;
  Timer? trackingTimer;
  final Box<LocationModel> locationBox = Hive.box<LocationModel>('locations');

  LocationModel? lastLocation;
  LocationModel? stopLocation;
  DateTime? stopStartTime;

  double totalDistance = 0.0;

  @override
  void dispose() {
    trackingTimer?.cancel();
    super.dispose();
  }


  void startTracking() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      final newPermission = await Geolocator.requestPermission();
      if (newPermission == LocationPermission.denied ||
          newPermission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
    }

    setState(() => isTracking = true);

    // Format current date as 'yyyy-MM-dd'
    final String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Handle the error appropriately (e.g., show login screen)
      print('No user logged in!');
      return;
    }
    final String engineerId = user.uid;

    trackingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
          ),
        );

        final location = LocationModel(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
        );

        // Save to Hive (local)
        await locationBox.add(location);
        print('Location saved locally: ${location.latitude}, ${location
            .longitude}');

        // Calculate distance
        if (lastLocation != null) {
          final distance = calculateDistance(
            lastLocation!.latitude, lastLocation!.longitude,
            location.latitude, location.longitude,
          );
          totalDistance += distance;
        }
        lastLocation = location;

        // Handle stop detection
        await handleStopDetection(location, engineerId, currentDate);

        // Save to Firebase
        final docRef = FirebaseFirestore.instance
            .collection('tracking')
            .doc(engineerId)
            .collection('trips')
            .doc(currentDate);

        final locationData = {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'timestamp': Timestamp.fromDate(location.timestamp),
        };

// Append the new location to the array
        await docRef.set({
          'trip_id': currentDate,
          'coord-ts': FieldValue.arrayUnion([locationData]),
          'distance_covered': totalDistance
        }, SetOptions(
            merge: true)); // merge to avoid overwriting previous locations


        print('Location also saved to Firebase');
      } catch (e) {
        print('Error during tracking: $e');
      }
    });
  }


  void stopTracking() {
    setState(() => isTracking = false);
    trackingTimer?.cancel();
    trackingTimer = null;
    print('Tracking stopped');
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371e3;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  Future<void> handleStopDetection(
      LocationModel currentLocation,
      String engineerId,
      String currentDate,
      ) async {
    const distanceThreshold = 50.0; // meters to consider it the same place
    const stopDurationThreshold = 5; // minutes to log a stop

    double currentLat = currentLocation.latitude;
    double currentLon = currentLocation.longitude;

    // Case 1: Already in a stop
    if (stopLocation != null) {
      final double dist = calculateDistance(
        stopLocation!.latitude,
        stopLocation!.longitude,
        currentLat,
        currentLon,
      );

      // Still at the same stop location
      if (dist < distanceThreshold) {
        if (stopStartTime != null &&
            DateTime.now().difference(stopStartTime!).inMinutes >= stopDurationThreshold) {

          final docRef = FirebaseFirestore.instance
              .collection('tracking')
              .doc(engineerId)
              .collection('trips')
              .doc(currentDate);

          final snapshot = await docRef.get();
          List<dynamic> stops = [];

          if (snapshot.exists && snapshot.data()!.containsKey('stops')) {
            stops = snapshot['stops'];
          }

          int? matchingIndex;
          for (int i = 0; i < stops.length; i++) {
            final stop = stops[i];
            final lat = stop['latitude'] ?? 0.0;
            final lon = stop['longitude'] ?? 0.0;
            final distToExisting = calculateDistance(lat, lon, currentLat, currentLon);

            if (distToExisting < distanceThreshold) {
              matchingIndex = i;
            }
          }

          if (matchingIndex != null) {
            // Update existing stop with new end time and duration
            final updatedStop = Map<String, dynamic>.from(stops[matchingIndex]);
            updatedStop['to'] = Timestamp.fromDate(DateTime.now());
            updatedStop['duration_minutes'] =
                DateTime.now().difference(stopStartTime!).inMinutes;

            stops[matchingIndex] = updatedStop;

            await docRef.update({'stops': stops});
            print('Updated existing stop: $updatedStop');
          } else {
            // Add new stop
            final stopData = {
              'latitude': currentLat,
              'longitude': currentLon,
              'from': Timestamp.fromDate(stopStartTime!),
              'to': Timestamp.fromDate(DateTime.now()),
              'duration_minutes':
              DateTime.now().difference(stopStartTime!).inMinutes,
            };

            await docRef.set({
              'stops': FieldValue.arrayUnion([stopData])
            }, SetOptions(merge: true));

            print('New stop added: $stopData');
          }

          // Do not reset stopStartTime or stopLocation here
          // unless user moves away
        }
      } else {
        // User moved significantly, reset stop tracking
        stopStartTime = DateTime.now();
        stopLocation = currentLocation;
      }
    } else {
      // First detection of potential stop
      stopStartTime = DateTime.now();
      stopLocation = currentLocation;
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
              "Field Engineer Tracker", style: TextStyle(color: Colors.white)),
        ),
        backgroundColor: Colors.deepOrangeAccent,
        elevation: 4,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            "Dashboard",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('tracking')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .collection('trips')
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final trips = snapshot.data!.docs;
                if (trips.isEmpty) {
                  return const Center(child: Text("No tracked sessions yet."));
                }

                return ListView.builder(
                  itemCount: trips.length,
                  itemBuilder: (context, index) {
                    final trip = trips[index].data() as Map<String, dynamic>;
                    final tripId = trip['trip_id'];
                    final distance = (trip['distance_covered'] ?? 0) / 1000.0;
                    final stops = (trip['stops'] ?? []).length;

                    final coords = trip['coord-ts'] as List<dynamic>?;
                    String timeSpent = 'N/A';
                    if (coords != null && coords.length > 1) {
                      final start = (coords.first['timestamp'] as Timestamp)
                          .toDate();
                      final end = (coords.last['timestamp'] as Timestamp)
                          .toDate();
                      final diff = end.difference(start);
                      timeSpent =
                      "${diff.inHours}h ${diff.inMinutes.remainder(60)}m";
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text("Trip: $tripId"),
                        subtitle: Text("📍 ${distance.toStringAsFixed(
                            2)} km | 🛑 $stops stops | ⏱ $timeSpent"),
                        trailing: const Icon(Icons.map),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FlutterMapPage(tripId: tripId,userId: FirebaseAuth.instance.currentUser?.uid),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => startTracking(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("Start Tracking",
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => stopTracking(),
                    icon: const Icon(Icons.stop),
                    label: const Text(
                        "Stop Tracking", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

