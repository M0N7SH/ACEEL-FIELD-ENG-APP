import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

Future<List<LatLng>> getSnappedRoute(List<LatLng> points) async {
  const maxWaypoints = 70;
  List<LatLng> snapped = [];

  for (int i = 0; i < points.length - 1; i += maxWaypoints - 1) {
    int end = (i + maxWaypoints < points.length) ? i + maxWaypoints : points.length;
    List<LatLng> chunk = points.sublist(i, end);

    try {
      final snappedChunk = await fetchSnappedChunk(chunk);
      if (snapped.isNotEmpty && snappedChunk.isNotEmpty) {
        // Avoid duplicating last point of previous chunk
        snappedChunk.removeAt(0);
      }
      snapped.addAll(snappedChunk);
    } catch (e) {
      print("Routing chunk error: $e");
    }
  }

  return snapped;
}

Future<List<LatLng>> fetchSnappedChunk(List<LatLng> coords) async {
  final apiKey = "5b3ce3597851110001cf6248bf89a735486d46069ea05b65b4006d7d";
  final uri = Uri.parse("https://api.openrouteservice.org/v2/directions/driving-car/geojson");

  final body = {
    "coordinates": coords.map((e) => [e.longitude, e.latitude]).toList(),
  };

  final response = await http.post(
    uri,
    headers: {
      'Authorization': apiKey,
      'Content-Type': 'application/json',
    },
    body: jsonEncode(body),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final coords = data['features'][0]['geometry']['coordinates'] as List;
    return coords.map((e) => LatLng(e[1], e[0])).toList();
  } else {
    throw Exception("Routing API error: ${response.body}");
  }
}
