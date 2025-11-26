import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // CORRECTED: Initialize with an empty map to prevent LateInitializationError
  Map _currentUser = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only initialize the first time using the route arguments
    if (_currentUser.isEmpty) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map) {
        _currentUser = args;
      }
    }
  }

  // Function to handle navigation to settings and update user data on return
  void _navigateToSettings() async {
    // Wait for the result (the updated user map) from the settings stack
    final updatedUser = await Navigator.pushNamed(
      context,
      '/settings',
      arguments: _currentUser,
    );

    // If we received an updated user object, update the state
    if (updatedUser != null && updatedUser is Map) {
      setState(() {
        _currentUser = updatedUser;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Safely extract data from _currentUser map
    final String userRole = _currentUser['role'] ?? 'user';
    final bool isAdmin = userRole == 'admin';
    final String userName = _currentUser['name'] ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text("Dashboard", style: TextStyle(fontSize: 16)),
            Text(
              "Hi, $userName",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed:
                _navigateToSettings, // Use the stateful navigation handler
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        children: [
          _DashboardTile(
            icon: Icons.directions_car,
            title: isAdmin ? "Manage Cars" : "View Cars",
            color: Colors.blue,
            onTap: () =>
                Navigator.pushNamed(context, '/cars', arguments: userRole),
          ),
          _DashboardTile(
            icon: Icons.contact_phone,
            title: "Dealer Contacts",
            color: Colors.orange,
            onTap: () =>
                Navigator.pushNamed(context, '/contacts', arguments: userRole),
          ),
          if (isAdmin)
            _DashboardTile(
              icon: Icons.bar_chart,
              title: "Sales Reports",
              color: Colors.green,
              onTap: () => Navigator.pushNamed(context, '/reports'),
            ),
          _DashboardTile(
            icon: Icons.settings,
            title: "Settings",
            color: Colors.grey,
            onTap: _navigateToSettings, // Use the stateful navigation handler
          ),
        ],
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _DashboardTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
