import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final String apiUrl = "http://localhost:3000/users";

  late Map initialUser;
  late int userId;
  late String userRole;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _initialized = false;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      // Get the full user object passed from settings
      initialUser = ModalRoute.of(context)!.settings.arguments as Map;
      userId = initialUser['id'];
      userRole = initialUser['role'];

      _nameController.text = initialUser['name'] ?? '';
      _emailController.text = initialUser['email'] ?? '';
      _passwordController.text = initialUser['password'] ?? '';

      _initialized = true;
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isSaving = true);

    // Construct the new user data payload
    final newUserData = {
      "name": _nameController.text,
      "email": _emailController.text,
      "password": _passwordController.text,
      "role": userRole, // Keep existing role
    };

    try {
      final response = await http.put(
        Uri.parse("$apiUrl/$userId"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(newUserData),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile Updated!"),
            backgroundColor: Colors.green,
          ),
        );

        // Construct the full updated user object to pass back
        final updatedUser = {
          'id': userId,
          'name': newUserData['name'],
          'email': newUserData['email'],
          'password': newUserData['password'],
          'role': newUserData['role'],
        };

        // Pop the profile screen and return the updated user object
        Navigator.pop(context, updatedUser);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Update Failed"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.indigo,
              child: Icon(Icons.person, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Full Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
              readOnly: true,
              enabled: false,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _updateProfile,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Save Changes",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
