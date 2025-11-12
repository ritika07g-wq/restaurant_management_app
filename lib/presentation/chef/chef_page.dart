import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For formatting timestamps
import '../login/screenlogin.dart'; // For logout navigation
import 'package:restaurant_app/presentation/settings/settingspage.dart'; // For settings navigation
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Authentication
import 'package:cloud_firestore/cloud_firestore.dart'; // Cloud Firestore

// Assuming MenuPage exists and is where the chef can view the restaurant's menu
import 'menu_page.dart'; // Keep this import as per user's original code
//1st change

class ChefPage extends StatefulWidget {
  // Assuming chefName and chefRole might be passed from login, similar to StaffPage
  final String? chefName;
  final String? chefRole;

  const ChefPage({super.key, this.chefName, this.chefRole});

  @override
  State<ChefPage> createState() => _ChefPageState();
}

class _ChefPageState extends State<ChefPage> {
  // --- Firebase Firestore Instance ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // For logout

  @override
  void initState() {
    super.initState();
    // No specific init for fetching needed here, StreamBuilders will handle it
  }

  // --- Modified Logout Function to use Firebase Auth ---
  void _logout() async {
    try {
      await _auth.signOut();
      if (!mounted) return; // Guard against using context if the widget is unmounted
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Screenlogin()),
        (route) => false,
      );
    } catch (e) {
      _showSnackBar('Error logging out: ${e.toString()}');
    }
  }

  // --- Helper to show snack bar messages ---
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // --- Navigation to Menu Page (as per original code) ---
  void _goToMenuPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MenuPage()),
    );
  }

  // --- Function to update order status in Firestore ---
  Future<void> _updateOrderStatus(String orderDocId, String newStatus) async {
    try {
      await _firestore.collection('orders').doc(orderDocId).update({
        'status': newStatus,
      });
      _showSnackBar('Order status updated to $newStatus');
    } catch (e) {
      _showSnackBar('Failed to update order status: ${e.toString()}');
    }
  }

  // --- Widget to display order details in a dialog (Modal Bottom Sheet) ---
  void _showOrderDetails(Map<String, dynamic> orderData, String orderDocId) {
    String updatedStatus = orderData['status'] ?? 'Unknown'; // Initialize with current status

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Wrap(
                children: [
                  Center(
                    child: Container(
                      height: 5,
                      width: 40,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  Text(
                    'Order ID: ${orderData['orderId'] ?? 'N/A'} - Table: ${orderData['tableNo'] ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Order Time: ${orderData['orderTime'] != null ? DateFormat('HH:mm').format((orderData['orderTime'] as Timestamp).toDate()) : 'N/A'}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Display order items
                  ... (orderData['items'] as List<dynamic>? ?? []).map<Widget>((item) {
                    if (item is Map<String, dynamic>) {
                      return ListTile(
                        leading: const Icon(Icons.fastfood),
                        title: Text(item['name'] ?? 'Unknown Item'),
                        trailing: Text('x${item['quantity'] ?? 1}'), // Use 'quantity' from Firestore
                      );
                    }
                    return const SizedBox.shrink();
                  }).toList(),
                  const Divider(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Update Status:',
                        style: TextStyle(fontSize: 16),
                      ),
                      DropdownButton<String>(
                        value: updatedStatus,
                        style: const TextStyle(color: Colors.black),
                        items: const [
                          DropdownMenuItem(
                            value: 'Pending', // Staff places as Pending
                            child: Text('Pending'),
                          ),
                          DropdownMenuItem(
                            value: 'Preparing',
                            child: Text('Preparing'),
                          ),
                          DropdownMenuItem(
                            value: 'Ready',
                            child: Text('Ready'),
                          ),
                          // Chef typically doesn't mark as Delivered/Cancelled
                        ],
                        onChanged: (value) {
                          setModalState(() { // Update local state in dialog
                            updatedStatus = value!;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Update status in Firestore
                      await _updateOrderStatus(orderDocId, updatedStatus);
                      if (mounted) Navigator.pop(context); // Close dialog
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Update & Close'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size.fromHeight(50),
                      textStyle: const TextStyle(fontSize: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Helper to build status badge (reused from original code) ---
  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    switch (status) {
      case 'Pending': // Orders start as Pending from Staff
        badgeColor = Colors.orange;
        break;
      case 'Preparing':
        badgeColor = Colors.blueAccent;
        break;
      case 'Ready': // Chef marks as Ready
        badgeColor = Colors.green;
        break;
      case 'Delivered': // Staff marks as Delivered
        badgeColor = Colors.purple;
        break;
      case 'Cancelled': // Can be cancelled by Staff
        badgeColor = Colors.red;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        border: Border.all(color: badgeColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: badgeColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 228, 228, 222),
      appBar: AppBar(
        title: Text(
          "Chef: ${widget.chefName ?? 'Chef'} (${widget.chefRole ?? 'Role Unknown'})",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: _goToMenuPage,
          ),
          IconButton(
            tooltip: 'Refresh Orders',
            icon: const Icon(Icons.refresh),
            onPressed: () {
            setState(() {}); // Forces UI refresh (Firestore stream auto-updates, but good for manual reload)
              },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsPage(role: 'chef'),
                  ),
                );
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Queue',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // 🆕 Order Cards Layout - Now using StreamBuilder
            Expanded( 
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('orders')
                    .where('status', whereIn: ['Pending', 'Preparing', 'Ready']) // Chef sees these statuses
                    .orderBy('orderTime', descending: false) // Oldest orders first
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading orders: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No active orders in the queue.'));
                  }

                  // Filter out 'Delivered' and 'Cancelled' if they somehow slip through
                  final filteredOrders = snapshot.data!.docs.where((doc) {
                    final status = (doc.data() as Map<String, dynamic>)['status'];
                    return status != 'Delivered' && status != 'Cancelled';
                  }).toList();

                  if (filteredOrders.isEmpty) {
                    return const Center(child: Text('No active orders in the queue.'));
                  }


                  return ListView.builder(
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final orderDocument = filteredOrders[index];
                      final orderData = orderDocument.data()! as Map<String, dynamic>;
                      
                      return InkWell(
                        onTap: () => _showOrderDetails(orderData, orderDocument.id), // Pass data and doc ID
                        child: Card(
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Order ID: ${orderData['orderId'] ?? 'N/A'}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Table: ${orderData['tableNo'] ?? 'N/A'}', // Use 'tableNo' from Firestore
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Items: ${orderData['items']?.map((item) => '${item['name']} x${item['quantity']}').join(', ') ?? 'N/A'}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildStatusBadge(orderData['status'] ?? 'Unknown'), // Use status from Firestore
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
