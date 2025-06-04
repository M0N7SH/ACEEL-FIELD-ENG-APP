import 'package:field_accel/pages/track_enginner.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class AdminView extends StatelessWidget {
  const AdminView({super.key});

  Future<List<Map<String, dynamic>>> fetchEngineers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'email': doc['email'],
      };
    }).toList();
  }

  void showEngineerDetails(BuildContext context, String userId, String email) async {
    final tripsSnapshot = await FirebaseFirestore.instance
        .collection('tracking')
        .doc(userId)
        .collection('trips')
        .get();

    double totalDistance = 0;
    int totalStops = 0;

    for (final trip in tripsSnapshot.docs) {
      final data = trip.data();
      final coords = List<Map<String, dynamic>>.from(data['coord-ts'] ?? []);
      final stops = List<Map<String, dynamic>>.from(data['stops'] ?? []);

      totalStops += stops.length;

      for (int i = 1; i < coords.length; i++) {
        final start = coords[i - 1];
        final end = coords[i];
        totalDistance += Geolocator.distanceBetween(
          start['latitude'], start['longitude'],
          end['latitude'], end['longitude'],
        );
      }
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Engineer: $email"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Total Distance: ${(totalDistance / 1000).toStringAsFixed(2)} km"),
            Text("Total Stops: $totalStops"),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin View")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackEngineersPage()));
          },
          child: const Text("Track Engineers"),
        ),
      ),
    );
  }
}
