import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/car_screen.dart';
import 'screens/dealer_contact_screen.dart';
import 'screens/sales_report_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/user_management_screen.dart';
import 'screens/user_profile_screen.dart'; // New Import

void main() {
  runApp(const CarDealerApp());
}

class CarDealerApp extends StatelessWidget {
  const CarDealerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Dealer App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/cars': (context) => const CarListScreen(),
        '/contacts': (context) => const DealerContactScreen(),
        '/reports': (context) => const SalesReportScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/users': (context) => const UserManagementScreen(),
        '/profile': (context) => const UserProfileScreen(), // New Route
      },
    );
  }
}
