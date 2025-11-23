import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // Navigation handler that can return data
  Future<void> _navigateToProfile(BuildContext context, Map user) async {
    // Await the result from the profile screen (which will be the updated user Map)
    final updatedUser = await Navigator.pushNamed(
      context,
      '/profile',
      arguments: user,
    );

    // If the user was updated, pop the settings screen and return the new data
    if (updatedUser != null && updatedUser is Map) {
      if (!context.mounted) return;
      // Pass the updated user object back to the Dashboard
      Navigator.pop(context, updatedUser);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get initial user object
    final Map user = ModalRoute.of(context)!.settings.arguments as Map;
    final String userRole = user['role'] ?? 'user';
    final bool isAdmin = userRole == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          const SizedBox(height: 10),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              "Account",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          // Profile Tile
          ListTile(
            leading: const Icon(Icons.person, color: Colors.purple),
            title: const Text("My Profile"),
            subtitle: const Text("Update name and password"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _navigateToProfile(context, user), // Use handler
          ),

          if (isAdmin) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "Admin Controls",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.people, color: Colors.blue),
              title: const Text("Manage Users"),
              subtitle: const Text("Add, Edit, or Remove App Users"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.pushNamed(context, '/users'),
            ),
          ],

          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              "App Info",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info, color: Colors.indigo),
            title: const Text("Version"),
            trailing: const Text("1.3.0"),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout"),
            onTap: () {
              // When logging out, we clear the whole route stack
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
        ],
      ),
    );
  }
}
