import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Import your screens
import 'presentation/splash/splash_screen.dart';
import 'presentation/login/screenlogin.dart';
import 'presentation/manager/manager_page.dart';
import 'presentation/chef/chef_page.dart';
import 'presentation/chef/menu_page.dart';
import 'presentation/staff/staff_page.dart';
import 'presentation/settings/settingspage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Restaurant Management App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),

      // 👇 Your first screen
      home: const SplashScreen(),

      // 👇 Named routes (optional but useful)
      routes: {
        '/login': (context) => const Screenlogin(),
        '/manager': (context) => ManagerPage(managerName: 'Default Manager'),
        '/chef': (context) => const ChefPage(),
        '/menu': (context) => const MenuPage(),
        '/staff': (context) => StaffPage(staffName: 'Staff', staffRole: 'Chef'),
        '/settings': (context) => SettingsPage(role: 'Admin'),
      },
    );
  }
}
