import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../login/screenlogin.dart';
import 'package:restaurant_app/presentation/settings/settingspage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StaffPage extends StatefulWidget {
  final String staffName;
  final String staffRole;

  const StaffPage({super.key, required this.staffName, required this.staffRole});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int selectedTableIndex = -1;
  final Map<String, Map<String, dynamic>> _selectedItemsWithDetails = {};
  String? _currentOrderId;
  String _orderStatus = 'Pending';
  String? _currentTableDocId;

  final TextEditingController _gstController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  // Logout
  void _logout() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Screenlogin()),
        (route) => false,
      );
    } catch (e) {
      _showSnackBar('Error logging out: ${e.toString()}');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _formatTableNumberForDisplay(String tableDocId) {
    if (tableDocId.startsWith('table_')) {
      return 'Table ${tableDocId.substring(6)}';
    }
    return tableDocId;
  }

  // ---------------------- TABLE SELECTION ----------------------
  Widget _buildTableSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select a Table:'),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('tables').orderBy('__name__').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('Error loading tables: ${snapshot.error}');
            if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Text('No tables found.');

            return Wrap(
              spacing: 10,
              children: snapshot.data!.docs.asMap().entries.map((entry) {
                final index = entry.key;
                final tableDoc = entry.value;
                final tableData = tableDoc.data()! as Map<String, dynamic>;
                final isOccupied = tableData['isOccupied'] ?? false;
                final String tableDisplayName = _formatTableNumberForDisplay(tableDoc.id);

                return ChoiceChip(
                  label: Text(tableDisplayName),
                  selected: selectedTableIndex == index,
                  onSelected: (bool selected) {
                    setState(() {
                      selectedTableIndex = selected ? index : -1;
                      _currentTableDocId = selected ? tableDoc.id : null;

                      if (selected && isOccupied && tableData['currentOrderId'] != null) {
                        _currentOrderId = tableData['currentOrderId'];

                        _firestore.collection('orders').doc(_currentOrderId).get().then((orderSnapshot) {
                          if (orderSnapshot.exists) {
                            setState(() {
                              _orderStatus = orderSnapshot.data()?['status'] ?? 'Unknown';
                            });
                          } else {
                            // Linked order missing -> free the table
                            _firestore.collection('tables').doc(tableDoc.id).update({
                              'isOccupied': false,
                              'currentOrderId': null,
                            });
                            setState(() {
                              _currentOrderId = null;
                              _orderStatus = 'Pending';
                            });
                            _showSnackBar('Linked order missing. Table reset to free.');
                          }
                        });
                      } else {
                        _currentOrderId = null;
                        _orderStatus = 'Pending';
                        _selectedItemsWithDetails.clear();
                      }
                    });
                  },
                  backgroundColor: isOccupied ? Colors.red[200] : Colors.green[200],
                  selectedColor: Colors.blue[400],
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ---------------------- MENU SELECTION ----------------------
  Widget _buildMenuItemSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Menu Items:'),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('menuItems').where('available', isEqualTo: true).orderBy('name').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('Error loading menu: ${snapshot.error}');
            if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Text('No menu items available.');

            return Wrap(
              spacing: 10,
              children: snapshot.data!.docs.map((document) {
                final itemData = document.data()! as Map<String, dynamic>;
                final itemId = document.id;
                final itemName = itemData['name'] ?? 'Unknown Item';
                final itemPrice = (itemData['price'] ?? 0.0).toDouble();

                return FilterChip(
                  label: Text('$itemName (\$${itemPrice.toStringAsFixed(2)})'),
                  selected: _selectedItemsWithDetails.containsKey(itemId),
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedItemsWithDetails[itemId] = {
                          ...itemData,
                          'quantity': 1
                        };
                      } else {
                        _selectedItemsWithDetails.remove(itemId);
                      }
                    });
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ---------------------- PLACE ORDER ----------------------
  void _placeOrderToFirestore() async {
    if (selectedTableIndex == -1) {
      _showSnackBar('Please select a table.');
      return;
    }
    if (_selectedItemsWithDetails.isEmpty) {
      _showSnackBar('Please select at least one menu item.');
      return;
    }
    if (_currentTableDocId == null) {
      _showSnackBar('Error: Selected table ID not found.');
      return;
    }
    if (_currentOrderId != null) {
      _showSnackBar('An order is already active for this table.');
      return;
    }

    try {
      List<Map<String, dynamic>> orderItems = _selectedItemsWithDetails.values.map((item) {
        return {
          'name': item['name'],
          'quantity': item['quantity'],
          'unitPrice': item['price'],
        };
      }).toList();

      DocumentReference orderRef = _firestore.collection('orders').doc();

      await orderRef.set({
        'orderId': orderRef.id, // actual Firestore ID
        'displayOrderId': orderRef.id.substring(0, 8), // for display only
        'tableNo': _currentTableDocId,
        'items': orderItems,
        'status': 'Pending',
        'orderTime': FieldValue.serverTimestamp(),
        'staffName': widget.staffName,
        'staffRole': widget.staffRole,
      });

      _currentOrderId = orderRef.id;
      _orderStatus = 'Pending';

      await _firestore.collection('tables').doc(_currentTableDocId).update({
        'isOccupied': true,
        'currentOrderId': _currentOrderId,
        'lastOccupiedTime': FieldValue.serverTimestamp(),
      });

      _showSnackBar('Order placed successfully! Order ID: ${orderRef.id}');
      setState(() {
        _selectedItemsWithDetails.clear();
      });
    } catch (e) {
      _showSnackBar('Failed to place order: ${e.toString()}');
    }
  }

  // ---------------------- MARK AS DELIVERED ----------------------
  void _markOrderAsDeliveredInFirestore() async {
    if (_currentOrderId == null) {
      _showSnackBar('No active order to mark as delivered.');
      return;
    }
    if (_orderStatus == 'Delivered' || _orderStatus == 'Cancelled') {
      _showSnackBar('Order is already $_orderStatus.');
      return;
    }

    try {
      await _firestore.collection('orders').doc(_currentOrderId).update({
        'status': 'Delivered',
      });
      _showSnackBar('Order marked as Delivered!');
      setState(() {
        _orderStatus = 'Delivered';
      });
    } catch (e) {
      _showSnackBar('Failed to mark as delivered: ${e.toString()}');
    }
  }

  // ---------------------- BILL GENERATION ----------------------
  void _generateBillAndReset() async {
    if (_currentOrderId == null) {
      _showSnackBar('No active order to generate bill for.');
      return;
    }
    if (_orderStatus != 'Delivered') {
      _showSnackBar('Order must be delivered first.');
      return;
    }
    if (_currentTableDocId == null) {
      _showSnackBar('Error: No table selected.');
      return;
    }

    try {
      final orderDoc = await _firestore.collection('orders').doc(_currentOrderId).get();
      if (!orderDoc.exists) {
        _showSnackBar('Error: Order details not found.');
        return;
      }
      final orderData = orderDoc.data()!;

      List<Map<String, dynamic>> billItems = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
      double itemTotal = 0;
      for (var item in billItems) {
        itemTotal += (item['quantity'] ?? 0) * (item['unitPrice'] ?? 0.0);
      }

      final String autoGeneratedBillId = _firestore.collection('bills').doc().id.substring(0, 8);
      _gstController.text = '5.0';
      _discountController.text = '0.0';

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Generate Bill'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Generated Bill ID: $autoGeneratedBillId'),
                TextField(controller: _gstController, decoration: const InputDecoration(labelText: 'GST %'), keyboardType: TextInputType.number),
                TextField(controller: _discountController, decoration: const InputDecoration(labelText: 'Discount Amount'), keyboardType: TextInputType.number),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Confirm Bill')),
            ],
          );
        },
      );

      double gstRate = double.tryParse(_gstController.text) ?? 0.0;
      double discountAmount = double.tryParse(_discountController.text) ?? 0.0;

      Map<String, dynamic> newBillData = {
        'orderId': orderData['orderId'],
        'billId': autoGeneratedBillId,
        'tableNo': orderData['tableNo'],
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'time': DateFormat('HH:mm').format(DateTime.now()),
        'items': billItems,
        'gst': gstRate,
        'discount': discountAmount,
        'createdAt': FieldValue.serverTimestamp(),
        'staffName': widget.staffName,
      };

      await _firestore.collection('bills').add(newBillData);
      if (mounted) _showBillDetailsDialog(newBillData);

      await _firestore.collection('tables').doc(_currentTableDocId).update({
        'isOccupied': false,
        'currentOrderId': null,
      });

      await _firestore.collection('orders').doc(_currentOrderId).delete();

      _showSnackBar('Bill generated and table reset!');
      setState(() {
        _currentOrderId = null;
        _orderStatus = 'Pending';
        _selectedItemsWithDetails.clear();
        selectedTableIndex = -1;
        _currentTableDocId = null;
      });
    } catch (e) {
      _showSnackBar('Failed to generate bill: ${e.toString()}');
    }
  }

  void _showBillDetailsDialog(Map<String, dynamic> bill) {
    double itemTotal = 0;
    List<dynamic> items = bill['items'] ?? [];
    for (var item in items) {
      if (item is Map<String, dynamic>) {
        itemTotal += (item['quantity'] ?? 0) * (item['unitPrice'] ?? 0.0);
      }
    }
    double gstAmount = itemTotal * ((bill['gst'] ?? 0.0) / 100);
    double grandTotal = itemTotal + gstAmount - (bill['discount'] ?? 0.0);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Bill Details"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Order ID: ${bill['orderId']}"),
                Text("Bill No: ${bill['billId']}"),
                Text("Date: ${bill['date']}"),
                Text("Time: ${bill['time']}"),
                const SizedBox(height: 10),
                const Text("Items Ordered:", style: TextStyle(fontWeight: FontWeight.bold)),
                ...items.map<Widget>((item) {
                  if (item is Map<String, dynamic>) {
                    double total = (item['quantity'] ?? 0) * (item['unitPrice'] ?? 0.0);
                    return Text(
                      "${item['name']} - Qty: ${item['quantity']}, Unit Price: \$${(item['unitPrice']).toStringAsFixed(2)}, Total: \$${total.toStringAsFixed(2)}",
                    );
                  }
                  return const SizedBox.shrink();
                }).toList(),
                const SizedBox(height: 10),
                Text("Subtotal: \$${itemTotal.toStringAsFixed(2)}"), 
                Text("GST (${bill['gst']}%): \$${gstAmount.toStringAsFixed(2)}"),
                Text("Discount: \$${bill['discount']}"),
                const Divider(),
                Text("Grand Total: \$${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Close"))],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.staffRole}: ${widget.staffName}", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage(role: 'staff')));
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(children: [Icon(Icons.settings), SizedBox(width: 8), Text('Settings')]),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(children: [Icon(Icons.exit_to_app), SizedBox(width: 8), Text('Logout')]),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTableSelection(),
            const SizedBox(height: 20),
            _buildMenuItemSelection(),
            const SizedBox(height: 20),
            const Text('Selected Items:'),
            Wrap(
              spacing: 8.0,
              children: _selectedItemsWithDetails.entries.map((entry) {
                final itemId = entry.key;
                final itemData = entry.value;
                return Chip(
                  label: Text('${itemData['name']} (Qty: ${itemData['quantity']}) \$${(itemData['price']).toStringAsFixed(2)}'),
                  onDeleted: () {
                    setState(() {
                      _selectedItemsWithDetails.remove(itemId);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: selectedTableIndex != -1 && _selectedItemsWithDetails.isNotEmpty && _currentOrderId == null
                  ? _placeOrderToFirestore
                  : null,
              child: const Text('Place Order'),
            ),
            const SizedBox(height: 10),
            _currentTableDocId != null
                ? StreamBuilder<DocumentSnapshot>(
                    stream: _firestore.collection('tables').doc(_currentTableDocId).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!.exists) return const Text('No active order for this table.');
                      final tableData = snapshot.data!.data() as Map<String, dynamic>;
                      final linkedOrderId = tableData['currentOrderId'];
                      if (linkedOrderId != null) {
                        return StreamBuilder<DocumentSnapshot>(
                          stream: _firestore.collection('orders').doc(linkedOrderId).snapshots(),
                          builder: (context, orderSnapshot) {
                            if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) return const Text('Linked order not found.');
                            final orderData = orderSnapshot.data!.data() as Map<String, dynamic>;
                            _orderStatus = orderData['status'] ?? 'Unknown';
                            _currentOrderId = orderSnapshot.data!.id;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Order ID: ${orderData['displayOrderId'] ?? orderData['orderId']}'),
                                Text('Order Status: $_orderStatus'),
                                ElevatedButton(
                                  onPressed: _orderStatus != 'Delivered' && _orderStatus != 'Cancelled'
                                      ? _markOrderAsDeliveredInFirestore
                                      : null,
                                  child: const Text('Mark as Delivered'),
                                ),
                                ElevatedButton(
                                  onPressed: _orderStatus == 'Delivered'
                                      ? _generateBillAndReset
                                      : null,
                                  child: const Text('Generate Bill'),
                                ),
                              ],
                            );
                          },
                        );
                      } else {
                        return const Text('No active order for this table.');
                      }
                    },
                  )
                : const Text('Select a table to manage its order.'),
          ],
        ),
      ),
    );
  }
}
