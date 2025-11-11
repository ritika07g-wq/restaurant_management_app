import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add Cloud Firestore import
//import 'package:firebase_auth/firebase_auth.dart'; // Add Firebase Auth import (for _showSnackBar, general good practice)

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  // --- Firebase Firestore Instance ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final FirebaseAuth _auth = FirebaseAuth.instance; // Not directly used for menu logic, but good for consistency if needed later

  // Removed: List<Map<String, dynamic>> menuItems = [...]; // Now fetched from Firestore

  // --- Helper to show snack bar messages ---
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // --- Function to toggle item availability in Firestore ---
  void _toggleAvailabilityInFirestore(String docId, bool currentAvailability) async {
    try {
      await _firestore.collection('menuItems').doc(docId).update({
        'available': !currentAvailability,
      });
      _showSnackBar('Item availability updated!');
    } catch (e) {
      _showSnackBar('Failed to update availability: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Menu'),
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('menuItems').orderBy('name').snapshots(), // Fetch all menu items, ordered by name
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading menu: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No menu items found. Please add some in Manager Page.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              DocumentSnapshot document = snapshot.data!.docs[index];
              Map<String, dynamic> item = document.data()! as Map<String, dynamic>;
              final String itemId = document.id; // Get Firestore document ID
              final bool isAvailable = item['available'] ?? false; // Default to false if field is missing

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(item['name'] ?? 'Unknown Item'),
                  subtitle: Text('₹${(item['price'] ?? 0).toStringAsFixed(2)}'), // Ensure price is displayed correctly
                  trailing: GestureDetector(
                    onTap: () => _toggleAvailabilityInFirestore(itemId, isAvailable), // Call Firestore update function
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.green[100] : Colors.red[100],
                        border: Border.all(
                          color: isAvailable ? Colors.green : Colors.red,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isAvailable ? 'Available' : 'Unavailable',
                        style: TextStyle(
                          color: isAvailable ? Colors.green[800] : Colors.red[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
