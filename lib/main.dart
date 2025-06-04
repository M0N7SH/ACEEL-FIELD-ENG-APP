import 'package:flutter/material.dart';
import 'package:field_accel/pages/dashboard.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'models/location_model.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth_gate.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized');
  } catch (e) {
    print('Firebase init error: $e');
  }

  try {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);
    print('Hive initialized');
  } catch (e) {
    print('Error initializing Hive: $e');
  }

  try {
    Hive.registerAdapter(LocationModelAdapter());
    print('LocationModelAdapter registered');
  } catch (e) {
    print('Error registering Hive adapter: $e');
  }

  try {
    await Hive.openBox<LocationModel>('locations');
    print('Hive box "locations" opened');
  } catch (e) {
    print('Error opening Hive box: $e');
  }

  try {
    await _checkAndRequestLocationPermission();
    await _initLocalNotifications();
    print('Location permission checked/requested');
  } catch (e) {
    print('Error requesting location permission: $e');
  }

  runApp(const MyApp());
}

Future<void> _initLocalNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(initSettings);
}

Future<void> _checkAndRequestLocationPermission() async {
  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      _showPermissionDeniedNotification();
    }
  }

  if (permission == LocationPermission.whileInUse) {
    permission = await Geolocator.requestPermission(); // Try requesting 'always' permission
    if (permission != LocationPermission.always) {
      _showPermissionDeniedNotification();
    }
  }

  if (!await Geolocator.isLocationServiceEnabled()) {
    _showLocationServiceDisabledDialog();
  }
}

void _showPermissionDeniedNotification() {
  const androidDetails = AndroidNotificationDetails(
    'permission_channel',
    'Permissions',
    channelDescription: 'Alerts when permissions are denied',
    importance: Importance.max,
    priority: Priority.high,
  );

  const platformDetails = NotificationDetails(android: androidDetails);
  flutterLocalNotificationsPlugin.show(
    0,
    'Permission Denied',
    'Location permission is required for tracking!',
    platformDetails,
  );
}

void _showLocationServiceDisabledDialog() {
  // Can't show dialogs from main directly—use notification or navigate to error screen
  flutterLocalNotificationsPlugin.show(
    1,
    'Location Service Off',
    'Please enable location services to use tracking features.',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'location_off_channel',
        'Location Off',
        channelDescription: 'Location services are off',
        importance: Importance.max,
        priority: Priority.high,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Field Engineer Tracker',
        theme: ThemeData(primarySwatch: Colors.deepOrange),
    home: AuthGate()); // Entry point goes through auth logic
  }
}
