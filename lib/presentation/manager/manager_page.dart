import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_app/presentation/login/screenlogin.dart';
import 'package:restaurant_app/presentation/settings/settingspage.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore

class ManagerPage extends StatefulWidget {
  final String managerName;

  const ManagerPage({
    super.key,
    required this.managerName,
  });

  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> with TickerProviderStateMixin {
  // --- Firebase Firestore Instance ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // For logout and user management

  String searchQuery = '';
  TextEditingController searchController = TextEditingController();
  String searchType = '';

  int selectedIndex = 0;
  late TabController _tabController;

  // --- Menu Item Controllers ---
  final TextEditingController _addMenuItemNameController = TextEditingController();
  final TextEditingController _addMenuItemPriceController = TextEditingController();
  final TextEditingController _addMenuItemCategoryController = TextEditingController(); // Added category field

  // --- Employee Controllers ---
  final TextEditingController _addEmployeeNameController = TextEditingController();
  final TextEditingController _addEmployeeAgeController = TextEditingController();
  final TextEditingController _addEmployeePhoneController = TextEditingController();
  final TextEditingController _addEmployeeUsernameController = TextEditingController(); // This will be the email
  final TextEditingController _addEmployeePasswordController = TextEditingController();
  final TextEditingController _addEmployeeIdController = TextEditingController();
  final TextEditingController _addEmployeeDateJoinedController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // --- Modified Logout Function to use Firebase Auth ---
  void _logout() async {
    try {
      await _auth.signOut();
      // Guard against using context if the widget is unmounted
      if (!mounted) return;
      // Navigate back to the login screen and remove all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Screenlogin()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      _showSnackBar('Error logging out: ${e.toString()}'); // Use e.toString() for consistency
    }
  }

  // --- Helper to show snack bar messages ---
  void _showSnackBar(String message) {
    if (mounted) { // Check if the widget is still in the widget tree
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<bool> selected = List.generate(5, (index) => index == selectedIndex);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Manager: ${widget.managerName}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsPage(role: 'manager'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ToggleButtons(
              isSelected: selected,
              onPressed: (index) => setState(() => selectedIndex = index),
              borderRadius: BorderRadius.circular(12),
              selectedColor: Colors.white,
              fillColor: Colors.blue,
              color: Colors.blue,
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Column(children: [Icon(Icons.group), SizedBox(height: 4), Text("Employees")]),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Column(children: [Icon(Icons.fastfood), SizedBox(height: 4), Text("Menu")]),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Column(children: [Icon(Icons.receipt), SizedBox(height: 4), Text("Orders")]),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Column(children: [Icon(Icons.payment), SizedBox(height: 4), Text("Bills")]),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Column(children: [Icon(Icons.history), SizedBox(height: 4), Text("History")]),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (selectedIndex == 0) _buildEmployeeSection(),
            if (selectedIndex == 1) _buildMenuDetails(),
            if (selectedIndex == 2) _buildOrdersSection(),
            if (selectedIndex == 3) _buildBillSection(),
            if (selectedIndex == 4) _buildHistorySection(),
          ],
        ),
      ),
    );
  }

  // --- Menu Management Functions ---

  // Function to add a new menu item to Firestore
  void _addMenuItemToFirestore() async {
    final name = _addMenuItemNameController.text.trim();
    final priceString = _addMenuItemPriceController.text.trim();
    final category = _addMenuItemCategoryController.text.trim();

    if (name.isEmpty || priceString.isEmpty || category.isEmpty) {
      _showSnackBar('Please fill all fields for the menu item.');
      return;
    }

    try {
      final double price = double.parse(priceString); // Convert price to double

      await _firestore.collection('menuItems').add({
        'name': name,
        'price': price,
        'category': category, // Store category
        'available': true, // Default status for new items
        'createdAt': FieldValue.serverTimestamp(), // Firestore timestamp
      });

      _addMenuItemNameController.clear();
      _addMenuItemPriceController.clear();
      _addMenuItemCategoryController.clear();
      _showSnackBar('Menu item added successfully!');
      if (mounted) Navigator.pop(context); // Close dialog after successful add
    } catch (e) {
      _showSnackBar('Failed to add item: ${e.toString()}');
      // Removed print statement as per request
    }
  }

  // Function to edit a menu item's price in Firestore
  void _editMenuItemInFirestore(String docId, String currentName, String currentCategory, double currentPrice) {
    final nameController = TextEditingController(text: currentName);
    final categoryController = TextEditingController(text: currentCategory);
    final priceController = TextEditingController(text: currentPrice.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Item: $currentName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Item Name')),
              TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Category')),
              TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price')),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                final newCategory = categoryController.text.trim();
                final newPriceString = priceController.text.trim();

                if (newName.isEmpty || newCategory.isEmpty || newPriceString.isEmpty) {
                  _showSnackBar('Please fill all fields to update.');
                  return;
                }

                try {
                  await _firestore.collection('menuItems').doc(docId).update({
                    'name': newName,
                    'category': newCategory,
                    'price': double.parse(newPriceString),
                  });
                  _showSnackBar('Menu item updated successfully!');
                  if (mounted) Navigator.of(context).pop();
                } catch (e) {
                  _showSnackBar('Failed to update item: ${e.toString()}');
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Function to remove a menu item from Firestore
  void _removeMenuItemFromFirestore(String docId, String itemName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: Text("Are you sure you want to remove '$itemName' from the menu?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await _firestore.collection('menuItems').doc(docId).delete();
                _showSnackBar('\'$itemName\' removed successfully!');
                if (mounted) Navigator.pop(context); // Close dialog
              } catch (e) {
                _showSnackBar('Failed to remove item: ${e.toString()}');
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // Dialog for adding a new menu item
  void _showAddMenuItemDialog() {
    _addMenuItemNameController.clear();
    _addMenuItemPriceController.clear();
    _addMenuItemCategoryController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Menu Item"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _addMenuItemNameController, decoration: const InputDecoration(labelText: "Item Name")),
              TextField(controller: _addMenuItemPriceController, decoration: const InputDecoration(labelText: "Price"), keyboardType: TextInputType.number),
              TextField(controller: _addMenuItemCategoryController, decoration: const InputDecoration(labelText: "Category (e.g., Appetizer, Main, Dessert)")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: _addMenuItemToFirestore, // Call the Firestore function
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  // Widget to build the Menu Details section using StreamBuilder
  Widget _buildMenuDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Menu Items:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('menuItems').orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error loading menu: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No menu items yet. Add some above!'));
            }

            return ListView.builder(
              shrinkWrap: true, // Important for nested list views in SingleChildScrollView
              physics: const NeverScrollableScrollPhysics(), // Prevent inner scrolling
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                DocumentSnapshot document = snapshot.data!.docs[index];
                Map<String, dynamic> data = document.data()! as Map<String, dynamic>;

                return Card(
                  child: ListTile(
                    title: Text(data['name'] ?? 'No Name'),
                    subtitle: Text(
                      "Price: \$${(data['price'] ?? 0.0).toStringAsFixed(2)} | Category: ${data['category'] ?? 'N/A'}",
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editMenuItemInFirestore(
                            document.id,
                            data['name'] ?? '',
                            data['category'] ?? '',
                            (data['price'] ?? 0.0).toDouble(), // Pass as double
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeMenuItemFromFirestore(
                            document.id,
                            data['name'] ?? 'Item',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _showAddMenuItemDialog,
          icon: const Icon(Icons.add),
          label: const Text("Add Item"),
        ),
      ],
    );
  }

  // --- Employee Management Functions ---

  // Function to add a new employee (user) to Firebase Auth and Firestore
  void _addEmployeeToFirestore(String role) async {
    final name = _addEmployeeNameController.text.trim();
    final age = _addEmployeeAgeController.text.trim();
    final phone = _addEmployeePhoneController.text.trim();
    final email = _addEmployeeUsernameController.text.trim(); // Username is email for Firebase Auth
    final password = _addEmployeePasswordController.text.trim();
    final employeeId = _addEmployeeIdController.text.trim();
    final dateJoined = _addEmployeeDateJoinedController.text.trim();

    if (name.isEmpty || age.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty || employeeId.isEmpty || dateJoined.isEmpty) {
      _showSnackBar('Please fill all fields for the new employee.');
      return;
    }

    try {
      // 1. Create user in Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Store user details in Firestore 'users' collection
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'age': age,
        'phone': phone,
        'username': email, // Storing email as username
        'role': role,
        'employeeId': employeeId, // Use a distinct field name to avoid conflict with Firestore doc ID
        'dateJoined': dateJoined,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _addEmployeeNameController.clear();
      _addEmployeeAgeController.clear();
      _addEmployeePhoneController.clear();
      _addEmployeeUsernameController.clear();
      _addEmployeePasswordController.clear();
      _addEmployeeIdController.clear();
      _addEmployeeDateJoinedController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());

      _showSnackBar('$role added successfully!');
      if (mounted) Navigator.pop(context); // Close dialog
    } on FirebaseAuthException catch (e) {
      _showSnackBar('Failed to add employee (Auth): ${e.message}');
      // Removed print statement as per request
    } catch (e) {
      _showSnackBar('Failed to add employee: ${e.toString()}');
      // Removed print statement as per request
    }
  }

  // Function to edit employee details in Firestore
  void _editEmployeeInFirestore(String docId, Map<String, dynamic> employeeData) {
    final nameController = TextEditingController(text: employeeData['name']);
    final ageController = TextEditingController(text: employeeData['age']);
    final phoneController = TextEditingController(text: employeeData['phone']);
    final usernameController = TextEditingController(text: employeeData['username']); // This is the email
    final passwordController = TextEditingController(); // Leave blank for no change
    final employeeIdController = TextEditingController(text: employeeData['employeeId']);
    final dateJoinedController = TextEditingController(text: employeeData['dateJoined']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Employee"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name")),
                TextField(controller: ageController, decoration: const InputDecoration(labelText: "Age")),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Phone")),
                TextField(controller: usernameController, decoration: const InputDecoration(labelText: "Email (Username)")),
                // Password field: In a real app, you'd have a separate "reset password" flow.
                // Direct update here only works for the currently logged-in user or with re-authentication.
                TextField(controller: passwordController, decoration: const InputDecoration(labelText: "Password (leave blank to keep current)"), obscureText: true),
                TextField(controller: employeeIdController, decoration: const InputDecoration(labelText: "Employee ID")),
                TextField(controller: dateJoinedController, decoration: const InputDecoration(labelText: "Date Joined")),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                final newAge = ageController.text.trim();
                final newPhone = phoneController.text.trim();
                final newEmail = usernameController.text.trim();
                final newPassword = passwordController.text.trim();
                final newEmployeeId = employeeIdController.text.trim();
                final newDateJoined = dateJoinedController.text.trim();

                if (newName.isEmpty || newAge.isEmpty || newPhone.isEmpty || newEmail.isEmpty || newEmployeeId.isEmpty || newDateJoined.isEmpty) {
                  _showSnackBar('Please fill all required fields to update.');
                  return;
                }

                try {
                  // Update Firestore document
                  await _firestore.collection('users').doc(docId).update({
                    'name': newName,
                    'age': newAge,
                    'phone': newPhone,
                    'username': newEmail,
                    'employeeId': newEmployeeId,
                    'dateJoined': newDateJoined,
                  });

                  // If email is changed, update in Firebase Auth as well
                  // This operation requires the user to be recently authenticated.
                  // For updating other users, you'd typically use Firebase Admin SDK (Cloud Functions).
                  User? currentUser = _auth.currentUser;
                  if (currentUser != null && currentUser.uid == docId && newEmail != employeeData['username']) {
                    await currentUser.verifyBeforeUpdateEmail(newEmail); // Using verifyBeforeUpdateEmail
                    _showSnackBar('Verification email sent to new email address. Please verify to complete email update.');
                  }

                  // Update password in Firebase Auth if provided
                  // This operation requires the user to be recently authenticated.
                  // For updating other users, you'd typically use Firebase Admin SDK (Cloud Functions).
                  if (currentUser != null && currentUser.uid == docId && newPassword.isNotEmpty) {
                    await currentUser.updatePassword(newPassword);
                  }

                  _showSnackBar('Employee details updated successfully!');
                  if (mounted) Navigator.pop(context);
                } on FirebaseAuthException catch (e) {
                  _showSnackBar('Failed to update employee (Auth): ${e.message}');
                  // Removed print statement as per request
                } catch (e) {
                  _showSnackBar('Failed to update employee: ${e.toString()}');
                  // Removed print statement as per request
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // Function to delete an employee from Firebase Auth and Firestore
  void _deleteEmployeeFromFirestore(String docId, String employeeName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: Text("Are you sure you want to remove '$employeeName'? This will delete their profile data. "
                     "Note: Deleting their login account (Firebase Auth) from the client-side for another user "
                     "is not directly supported and would require a backend solution (e.g., Cloud Function)."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                // Only deleting the Firestore document here.
                // Deleting the Firebase Auth user for another user requires Firebase Admin SDK.
                await _firestore.collection('users').doc(docId).delete();

                _showSnackBar('\'$employeeName\' removed successfully!');
                if (mounted) Navigator.pop(context); // Close dialog
              } catch (e) {
                _showSnackBar('Failed to remove employee: ${e.toString()}');
                // Removed print statement as per request
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // Dialog for adding a new employee
  void _showAddEmployeeDialog(String role) {
    _addEmployeeNameController.clear();
    _addEmployeeAgeController.clear();
    _addEmployeePhoneController.clear();
    _addEmployeeUsernameController.clear();
    _addEmployeePasswordController.clear();
    _addEmployeeIdController.clear();
    _addEmployeeDateJoinedController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add New $role"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: _addEmployeeNameController, decoration: const InputDecoration(labelText: "Name")),
                TextField(controller: _addEmployeeAgeController, decoration: const InputDecoration(labelText: "Age")),
                TextField(controller: _addEmployeePhoneController, decoration: const InputDecoration(labelText: "Phone")),
                TextField(controller: _addEmployeeUsernameController, decoration: const InputDecoration(labelText: "Email (Username)")),
                TextField(controller: _addEmployeePasswordController, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
                TextField(controller: _addEmployeeIdController, decoration: const InputDecoration(labelText: "Employee ID")),
                TextField(controller: _addEmployeeDateJoinedController, decoration: const InputDecoration(labelText: "Date Joined"), readOnly: true), // Date is auto-filled
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => _addEmployeeToFirestore(role), // Pass the role
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  // Widget to display employee details in a dialog
  void _showEmployeeDetailsDialog(Map<String, dynamic> employeeData, String docId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Employee Details"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Name: ${employeeData['name'] ?? 'N/A'}"),
              Text("Age: ${employeeData['age'] ?? 'N/A'}"),
              Text("Phone: ${employeeData['phone'] ?? 'N/A'}"),
              Text("Email (Username): ${employeeData['username'] ?? 'N/A'}"),
              Text("Role: ${employeeData['role'] ?? 'N/A'}"),
              Text("Employee ID: ${employeeData['employeeId'] ?? 'N/A'}"),
              Text("Date Joined: ${employeeData['dateJoined'] ?? 'N/A'}"),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close current dialog
                      _editEmployeeInFirestore(docId, employeeData); // Pass docId and data
                    },
                    child: const Text("Edit"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      Navigator.pop(context); // Close current dialog
                      _deleteEmployeeFromFirestore(docId, employeeData['name'] ?? 'Employee');
                    },
                    child: const Text("Delete"),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Widget to build the Employee Section with Staff and Chefs tabs
  Widget _buildEmployeeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [Tab(text: "Staff"), Tab(text: "Chefs")],
        ),
        SizedBox(
          height: 400, // Fixed height for TabBarView
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildEmployeeList("Staff"), // Pass role directly
              _buildEmployeeList("Chef"), // Pass role directly
            ],
          ),
        ),
      ],
    );
  }

  // Widget to build a list of employees based on role
  Widget _buildEmployeeList(String role) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').where('role', isEqualTo: role).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading $role: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No $role members found.'));
        }

        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            ...snapshot.data!.docs.map((document) {
              Map<String, dynamic> employee = document.data()! as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text("${employee['name'] ?? 'N/A'}"),
                  subtitle: Text("ID: ${employee['employeeId'] ?? 'N/A'}"),
                  onTap: () {
                    _showEmployeeDetailsDialog(employee, document.id); // Pass document data and ID
                  },
                ),
              );
            }).toList(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  _showAddEmployeeDialog(role); // Pass role to dialog
                },
                child: Text("Add $role"),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Orders Management Functions ---

  // Widget to build the Orders Section using StreamBuilder
  Widget _buildOrdersSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("Current Orders:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('orders').orderBy('orderTime', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading orders: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No active orders found.'));
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              DocumentSnapshot document = snapshot.data!.docs[index];
              Map<String, dynamic> order = document.data()! as Map<String, dynamic>;

              return Card(
                child: ListTile(
                  title: Text('Order ID: ${order['orderId'] ?? 'N/A'} (Table: ${order['tableNo'] ?? 'N/A'})'),
                  // Show status but disable editing
                  subtitle: Text('Status: ${order['status'] ?? 'N/A'}'),
                  trailing: Chip(
                    label: Text(
                      order['status'] ?? 'N/A',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: _getStatusColor(order['status']),
                  ),
                  onTap: () {
                    _showOrderDetailsDialog(order);
                  },
                ),
              );
            },
          );
        },
      ),
    ],
  );
}

// Optional helper to set color based on status
Color _getStatusColor(String? status) {
  switch (status) {
    case 'Pending':
      return Colors.orange;
    case 'Preparing':
      return Colors.blue;
    case 'Ready':
      return Colors.green;
    case 'Served':
      return Colors.grey;
    case 'Cancelled':
      return Colors.red;
    default:
      return Colors.black54;
  }
}


  // Dialog to show order details
  void _showOrderDetailsDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Order Details"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Order ID: ${order['orderId'] ?? 'N/A'}"),
              Text("Table No: ${order['tableNo'] ?? 'N/A'}"),
              Text("Order Time: ${order['orderTime'] != null ? DateFormat('yyyy-MM-dd HH:mm').format((order['orderTime'] as Timestamp).toDate()) : 'N/A'}"),
              const SizedBox(height: 10),
              const Text("Items Ordered:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              // Display table headers and items with their quantity
              // Assuming 'items' in order is a List of Maps like [{'name': 'Pizza', 'quantity': 2}]
              _buildItemsTable(order['items'] as List<dynamic>? ?? []),
              const SizedBox(height: 10),
              Text("Order Status: ${order['status'] ?? 'N/A'}"),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  // Helper widget to build the items table for order details
  Widget _buildItemsTable(List<dynamic> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          children: items.map<Widget>((item) {
            // Ensure item is a Map<String, dynamic>
            if (item is Map<String, dynamic>) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item['name'] ?? 'Unknown Item'),
                    Text('X ${item['quantity'] ?? 1}'),
                  ],
                ),
              );
            }
            return const SizedBox.shrink(); // Handle unexpected item format
          }).toList(),
        ),
      ],
    );
  }

  // --- Bills and History Management Functions ---

  // Widget to build the Bills Section (Today's Bills)
  Widget _buildBillSection() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Today's Bills:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('bills').where('date', isEqualTo: today).orderBy('time', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error loading today\'s bills: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No bills for today."));
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                DocumentSnapshot document = snapshot.data!.docs[index];
                Map<String, dynamic> bill = document.data()! as Map<String, dynamic>;
                return Card(
                  child: ListTile(
                    title: Text('Order ID: ${bill['orderId'] ?? 'N/A'} (Bill ID: ${bill['billId'] ?? 'N/A'})'),
                    subtitle: Text('Table No: ${bill['tableNo'] ?? 'N/A'} - ${bill['time'] ?? 'N/A'}'),
                    onTap: () => _showBillDetailsDialog(bill),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // Widget to build the History Section (All Bills with Search/Filter)
  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchBar(), // This will be the search bar and filter controls
        const SizedBox(height: 16),
        const Text("Order History:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('bills').orderBy('date', descending: true).orderBy('time', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error loading order history: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No order history found.'));
            }

            // Filter bills based on search query and type
            List<Map<String, dynamic>> filteredBills = snapshot.data!.docs.map((doc) => doc.data()! as Map<String, dynamic>).where((bill) {
              if (searchQuery.isEmpty) return true; // No filter, show all bills

              switch (searchType) {
                case 'orderId':
                  return (bill['orderId']?.toString() ?? '').toLowerCase().contains(searchQuery.toLowerCase());
                case 'tableNo':
                  return (bill['tableNo']?.toString() ?? '').toLowerCase().contains(searchQuery.toLowerCase());
                case 'date':
                  return (bill['date']?.toString() ?? '').toLowerCase().contains(searchQuery.toLowerCase());
                default:
                  return true; // Show all if no filter is selected
              }
            }).toList();

            // Group filtered bills by date
            Map<String, List<Map<String, dynamic>>> groupedBills = {};
            for (var bill in filteredBills) {
              String date = bill['date'] ?? 'Unknown Date';
              if (!groupedBills.containsKey(date)) {
                groupedBills[date] = [];
              }
              groupedBills[date]!.add(bill);
            }

            List<String> sortedDates = groupedBills.keys.toList()..sort((a, b) => b.compareTo(a)); // Sort dates descending

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedDates.length,
              itemBuilder: (context, dateIndex) {
                String date = sortedDates[dateIndex];
                List<Map<String, dynamic>> billsForDate = groupedBills[date]!;
                return _buildDateSection(date, billsForDate);
              },
            );
          },
        ),
      ],
    );
  }

  // Widget to build a section for a specific date in history
  Widget _buildDateSection(String date, List<Map<String, dynamic>> bills) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            date,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        ...bills.map((bill) {
          return Card(
            child: ListTile(
              title: Text('Order ID: ${bill['orderId'] ?? 'N/A'} (Bill ID: ${bill['billId'] ?? 'N/A'})'),
              subtitle: Text('Table No: ${bill['tableNo'] ?? 'N/A'} - ${bill['time'] ?? 'N/A'}'),
              onTap: () => _showBillDetailsDialog(bill),
            ),
          );
        }).toList(),
      ],
    );
  }

  // Dialog to show bill details
  void _showBillDetailsDialog(Map<String, dynamic> bill) {
    double itemTotal = 0;
    List<dynamic> items = bill['items'] as List<dynamic>? ?? [];
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
                Text("Order ID: ${bill['orderId'] ?? 'N/A'}"),
                Text("Bill No: ${bill['billId'] ?? 'N/A'}"),
                Text("Date: ${bill['date'] ?? 'N/A'}"),
                Text("Time: ${bill['time'] ?? 'N/A'}"),
                const SizedBox(height: 10),
                const Text("Items Ordered:", style: TextStyle(fontWeight: FontWeight.bold)),
                ...items.map<Widget>((item) {
                  if (item is Map<String, dynamic>) {
                    double total = (item['quantity'] ?? 0) * (item['unitPrice'] ?? 0.0);
                    return Text(
                      "${item['name'] ?? 'Unknown'} - Qty: ${item['quantity'] ?? 0}, Unit Price: \$${(item['unitPrice'] ?? 0.0).toStringAsFixed(2)}, Total: \$${total.toStringAsFixed(2)}",
                    );
                  }
                  return const SizedBox.shrink();
                }).toList(),
                const SizedBox(height: 10),
                Text("Subtotal: \$${itemTotal.toStringAsFixed(2)}"),
                Text("GST (${(bill['gst'] ?? 0.0).toStringAsFixed(2)}%): \$${gstAmount.toStringAsFixed(2)}"),
                Text("Discount: \$${(bill['discount'] ?? 0.0).toStringAsFixed(2)}"),
                const Divider(),
                Text("Grand Total: \$${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  // --- Search Bar Widget ---
  Widget _buildSearchBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Search TextField
        Expanded(
          child: TextField(
            controller: searchController, // Use a controller for clearing
            onChanged: (query) {
              setState(() {
                searchQuery = query;
              });
            },
            decoration: InputDecoration(
              hintText: "Search...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Filter Dropdown
        DropdownButton<String>(
          hint: const Text("Filter by"),
          value: searchType.isEmpty ? null : searchType,
          items: const [
            DropdownMenuItem(value: 'orderId', child: Text('Order ID')),
            DropdownMenuItem(value: 'tableNo', child: Text('Table No')),
            DropdownMenuItem(value: 'date', child: Text('Date')),
          ],
          onChanged: (value) {
            setState(() {
              searchType = value ?? '';
            });
          },
        ),
        const SizedBox(width: 8),
        // Clear Filter Button
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            setState(() {
              searchQuery = '';
              searchType = '';
              searchController.clear(); // Clear the text field
            });
          },
        ),
      ],
    );
  }
}
