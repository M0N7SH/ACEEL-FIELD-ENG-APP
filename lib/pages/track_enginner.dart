import 'package:field_accel/pages/google_map.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrackEngineersPage extends StatefulWidget {
  const TrackEngineersPage({super.key});

  @override
  State<TrackEngineersPage> createState() => _TrackEngineersPageState();
}

class _TrackEngineersPageState extends State<TrackEngineersPage> {
  String? selectedUserId;
  String? selectedDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text("Engineer Tracker", style: TextStyle(color: Colors.white)),
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: Row(
        children: [
          _buildUserPane(),
          _buildDatePane(),
          _buildTrackingDetailsPane(),
        ],
      ),
    );
  }

  // ------------------ Left Pane (User List) -------------------
  Widget _buildUserPane() {
    return Expanded(
      flex: 2,
      child: Container(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey.shade400)),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Engineers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: _buildUserList()),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var users = snapshot.data!.docs;
        return ListView.separated(
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            var userDoc = users[index];
            String name = userDoc['email'] ?? 'Unnamed';
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedUserId == userDoc.id ? Colors.deepPurple : null,
                foregroundColor: selectedUserId == userDoc.id ? Colors.white : null,
              ),
              onPressed: () {
                setState(() {
                  selectedUserId = userDoc.id;
                  selectedDate = null;
                });
              },
              child: Text(name),
            );
          },
        );
      },
    );
  }

  // ------------------ Middle Pane (Dates) -------------------
  Widget _buildDatePane() {
    return Expanded(
      flex: 2,
      child: Container(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey.shade400)),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Dates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            selectedUserId == null
                ? const Center(child: Text("Select an engineer"))
                : Expanded(child: _buildDateList()),
          ],
        ),
      ),
    );
  }

  Widget _buildDateList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tracking')
          .doc(selectedUserId)
          .collection('trips')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var dateDocs = snapshot.data!.docs;
        if (dateDocs.isEmpty) return const Center(child: Text("No tracking data"));

        return ListView.separated(
          itemCount: dateDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            String date = dateDocs[index].id;
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedDate == date ? Colors.deepPurple : null,
                foregroundColor: selectedDate == date ? Colors.white : null,
              ),
              onPressed: () {
                setState(() {
                  selectedDate = date;
                });
              },
              child: Text(date),
            );
          },
        );
      },
    );
  }

  // ------------------ Right Pane (Details) -------------------
  Widget _buildTrackingDetailsPane() {
    return Expanded(
      flex: 3,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Tracking Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            (selectedUserId == null || selectedDate == null)
                ? const Expanded(child: Center(child: Text("Select engineer and date")))
                : Expanded(child: _buildTrackingDetails()),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingDetails() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('tracking')
          .doc(selectedUserId)
          .collection('trips')
          .doc(selectedDate)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.data() as Map<String, dynamic>?;

        if (data == null) return const Center(child: Text("No tracking data available"));

        double distance = data['distance_covered'] ?? 0.0;
        int stops = (data['stops'] as List?)?.length ?? 0;
        final tripId = data['trip_id'] ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: const Text("Distance Covered"),
              subtitle: Text("${(distance / 1000).toStringAsFixed(2)} km"),
            ),
            ListTile(
              title: const Text("Number of Stops"),
              subtitle: Text("$stops"),
            ),
            const SizedBox(height: 12),
            const Text("Route Map", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                color: Colors.grey.shade300,
                child: FlutterMapPage(tripId: tripId,
                userId: selectedUserId!),
              ),
            ),
          ],
        );
      },
    );
  }
}
