import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsPage extends StatefulWidget {
  final String role;

  const SettingsPage({super.key, required this.role});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool notificationsEnabled = true;
  bool darkModeEnabled = false;
  String selectedLanguage = 'English';

  Map<String, dynamic> _userProfileData = {};
  bool _isProfileLoading = true;
  ImageProvider? profileImage;

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  bool get isManager => widget.role.toLowerCase() == 'manager';

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        _showSnackBar('User not logged in.');
        setState(() => _isProfileLoading = false);
      }
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        if (mounted) {
          setState(() {
            _userProfileData = userDoc.data()!;
            _isProfileLoading = false;
          });
        }
      } else {
        if (mounted) {
          _showSnackBar('User profile not found in Firestore.');
          setState(() => _isProfileLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to load profile: ${e.toString()}');
        setState(() => _isProfileLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _handleProfileSettingsTap() {
    if (_userProfileData.isNotEmpty) {
      _showEditProfileDialog();
    } else {
      _showSnackBar('Profile data is not available yet. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isProfileLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text(
              'Account Settings',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          // Profile Settings - always enabled
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile Settings'),
            onTap: _handleProfileSettingsTap,
          ),
          // Change Password - only enabled for Manager
          ListTile(
            leading: Icon(Icons.lock, color: isManager ? Colors.black : Colors.grey),
            title: Text(
              'Change Password',
              style: TextStyle(
                color: isManager ? Colors.black : Colors.grey,
              ),
            ),
            enabled: isManager,
            onTap: isManager
                ? _showChangePasswordDialog
                : () => _showSnackBar("Only managers can change password"),
          ),
          const Divider(),
          const ListTile(
            title: Text(
              'App Settings',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            value: notificationsEnabled,
            onChanged: (bool value) {
              setState(() {
                notificationsEnabled = value;
              });
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            value: darkModeEnabled,
            onChanged: (bool value) {
              setState(() {
                darkModeEnabled = value;
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            trailing: DropdownButton<String>(
              value: selectedLanguage,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedLanguage = newValue;
                  });
                }
              },
              items: ['English', 'Spanish', 'French', 'German']
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
            ),
          ),
          const Divider(),
          const ListTile(
            title: Text(
              'About',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('App Version'),
            trailing: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms & Conditions'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameController =
        TextEditingController(text: _userProfileData['name'] ?? '');
    final usernameController =
        TextEditingController(text: _userProfileData['username'] ?? '');
    final phoneController =
        TextEditingController(text: _userProfileData['phone'] ?? '');
    final ageController =
        TextEditingController(text: _userProfileData['age'] ?? '');
    final emailController =
        TextEditingController(text: _userProfileData['username'] ?? '');
    final genderController =
        TextEditingController(text: _userProfileData['gender'] ?? '');

    if (_userProfileData.isEmpty) {
      _showSnackBar('Profile data not yet loaded. Please try again.');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  _showSnackBar('Profile image change is not yet implemented.');
                },
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage:
                      profileImage ?? const AssetImage('assets/placeholder.png'),
                  child: profileImage == null
                      ? const Icon(Icons.add_a_photo)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: usernameController, decoration: const InputDecoration(labelText: 'Username'), readOnly: true),
              TextField(controller: ageController, decoration: const InputDecoration(labelText: 'Age')),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone Number')),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email'), readOnly: true),
              TextField(controller: genderController, decoration: const InputDecoration(labelText: 'Gender')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _updateProfileInFirestore(
                name: nameController.text.trim(),
                age: ageController.text.trim(),
                phone: phoneController.text.trim(),
                gender: genderController.text.trim(),
              );
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfileInFirestore({
    required String name,
    required String age,
    required String phone,
    required String gender,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      _showSnackBar('User not logged in.');
      return;
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'name': name,
        'age': age,
        'phone': phone,
        'gender': gender,
      });
      _showSnackBar('Profile updated successfully!');
      _fetchUserProfile();
    } catch (e) {
      _showSnackBar('Failed to update profile: ${e.toString()}');
    }
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: _obscureCurrentPassword,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureCurrentPassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setModalState(() =>
                            _obscureCurrentPassword = !_obscureCurrentPassword);
                      },
                    ),
                  ),
                ),
                TextField(
                  controller: newPasswordController,
                  obscureText: _obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNewPassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setModalState(() =>
                            _obscureNewPassword = !_obscureNewPassword);
                      },
                    ),
                  ),
                ),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setModalState(() =>
                            _obscureConfirmPassword =
                                !_obscureConfirmPassword);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final currentPassword = currentPasswordController.text.trim();
                final newPassword = newPasswordController.text.trim();
                final confirmPassword =
                    confirmPasswordController.text.trim();

                if (newPassword != confirmPassword) {
                  _showSnackBar('New password and confirmation do not match.');
                  return;
                }

                if (currentPassword.isEmpty || newPassword.isEmpty) {
                  _showSnackBar('All password fields are required.');
                  return;
                }

                await _changePassword(currentPassword, newPassword);
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword(
      String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      _showSnackBar('User not logged in.');
      return;
    }

    try {
      final AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      _showSnackBar('Password changed successfully!');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        _showSnackBar('Incorrect current password.');
      } else {
        _showSnackBar('Failed to change password: ${e.message}');
      }
    } catch (e) {
      _showSnackBar('An unexpected error occurred: ${e.toString()}');
    }
  }
}
