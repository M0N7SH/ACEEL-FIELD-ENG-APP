import 'package:field_accel/pages/admin_view.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:field_accel/pages/admin_view.dart';
import 'package:field_accel/pages/dashboard.dart';

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLogin = true;
  String errorMessage = '';
  bool isLoading = false;

  Future<bool> isRegisteredUser(String email) async {
    final userQuery = await FirebaseFirestore.instance
        .collection('registered_users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    return userQuery.docs.isNotEmpty;
  }
  Future<String?> _promptForName(BuildContext context) async {
    TextEditingController nameController = TextEditingController();

    return showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Enter Your Name"),
            content: TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: "Name"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(), // cancel
                child: Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(nameController.text),
                child: Text("OK"),
              ),
            ],
          );
        }
    );
    }

  Future<bool> isAdminUser(String email) async {
    print('hello');
    final adminQuery = await FirebaseFirestore.instance
        .collection('admin')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    print('Admin docs found: ${adminQuery.docs.length}');
    if (adminQuery.docs.isNotEmpty) {
      print('Admin found: ${adminQuery.docs.first.data()}');
    }
    return adminQuery.docs.isNotEmpty;
  }

  Future<void> handleAuth() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      final isAdmin = await isAdminUser(email);

      // If not admin, check if registered user
      if (!isAdmin) {
        final isRegistered = await isRegisteredUser(email);
        if (!isRegistered) {
          setState(() {
            isLoading = false;
            errorMessage = 'Email is not registered. Contact admin.';
          });
          return;
        }
      }

      UserCredential userCredential;
      if (isLogin) {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final uid = userCredential.user!.uid;
        String? name = await _promptForName(context);
        if (name == null || name.isEmpty) {
          throw Exception("Name required");
        }
        // Save to Firestore
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': name,
          'email': email,
        });
      }

      if (!mounted) return;
      if (isAdmin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminView()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => Dashboard()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.message ?? 'Something went wrong';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.deepOrange),
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.2),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 60, color: Colors.deepOrange),
                SizedBox(height: 20),
                Text(
                  isLogin ? 'Welcome Back' : 'Create Account',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  isLogin
                      ? 'Please login to your account'
                      : 'Register to get started',
                  style: TextStyle(fontSize: 16, color: Colors.deepOrange),
                ),
                SizedBox(height: 30),
                if (errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      errorMessage,
                      style: TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration("Email", Icons.email),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: _inputDecoration("Password", Icons.lock),
                ),
                SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : handleAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 5,
                    ),
                    child: isLoading
                        ? CircularProgressIndicator(
                      color: Colors.white,
                    )
                        : Text(
                      isLogin ? 'Login' : 'Register',
                      style: TextStyle(fontSize: 18,color: Colors.white),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isLogin = !isLogin;
                      errorMessage = '';
                    });
                  },
                  child: Text(
                    isLogin
                        ? "Don't have an account? Register"
                        : "Already have an account? Login",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.deepOrange,
                      decoration: TextDecoration.underline,

                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
