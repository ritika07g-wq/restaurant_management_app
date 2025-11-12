import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:restaurant_app/presentation/manager/manager_page.dart';
import 'package:restaurant_app/presentation/staff/staff_page.dart';
import 'package:restaurant_app/presentation/chef/chef_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Screenlogin extends StatefulWidget {
  const Screenlogin({super.key});

  @override
  State<Screenlogin> createState() => _ScreenloginState();
}

class _ScreenloginState extends State<Screenlogin> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _errorMessage;

 void _handleLogin() async {
  final email = _usernameController.text.trim(); // now used as email
  final password = _passwordController.text.trim(); // now used as password
  //first change made
  if (_formKey.currentState!.validate()) {
    try {
      // 🔐 Sign in using Firebase Auth
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      // 🔍 Fetch user role from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        setState(() {
          _errorMessage = "No user data found in Firestore.";
        });
        return;
      }

      final role = userDoc.data()?['role'];
      final name = userDoc.data()?['name'];

      if (role == 'Manager') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ManagerPage(managerName: name)),
        );
      } else if (role == 'Staff') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => StaffPage(staffName: name, staffRole: role)),
        );
      } else if (role == 'Chef') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ChefPage()),
        );
      } else {
        setState(() {
          _errorMessage = "Unknown role: $role";
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = "Login failed: ${e.message}";
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Something went wrong. Try again.";
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset(
            'assets/images/bg.jpg',
            fit: BoxFit.cover,
          ),

          // Blur filter
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
            child: Container(
              color: Colors.black.withOpacity(0.1),
            ),
          ),

          // Login content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Italiano",
                    style: GoogleFonts.pacifico(
                      fontSize: 45,
                      color: const Color.fromARGB(255, 0, 11, 30),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    margin: const EdgeInsets.all(8),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Login",
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                            ),
                            const SizedBox(height: 32),
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: 'Email ID',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.person),
                              ),
                              validator: (value) => value!.isEmpty
                                  ? 'Please enter username'
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.lock),
                              ),
                              obscureText: true,
                              validator: (value) => value!.isEmpty
                                  ? 'Please enter password'
                                  : null,
                            ),
                            const SizedBox(height: 30),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                backgroundColor:
                                    const Color.fromARGB(255, 164, 208, 245),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _handleLogin,
                              child: const Text(
                                "Login",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
