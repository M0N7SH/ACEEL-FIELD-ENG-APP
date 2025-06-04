import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'pages/login_signup_page.dart';
import 'pages/dashboard.dart';
import 'pages/admin_view.dart';

class AuthGate extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();

  AuthGate({super.key});

  Future<bool> checkIfAdmin(String email) async {
    final adminQuery = await FirebaseFirestore.instance
        .collection('admin')
        .where('email', isEqualTo: email)
        .get();
    return adminQuery.docs.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasData && snapshot.data != null) {
                final user = snapshot.data!;
                return FutureBuilder<bool>(
                  future: checkIfAdmin(user.email!),
                  builder: (context, adminSnapshot) {
                    if (!adminSnapshot.hasData) {
                      return Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (adminSnapshot.data == true) {
                      return AdminView();
                    } else {
                      return Dashboard();
                    }
                  },
                );
              }

              return LoginPage();
            },
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Firebase Init Error: ${snapshot.error}')),
          );
        }

        return Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
