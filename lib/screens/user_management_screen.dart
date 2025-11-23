import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final String apiUrl = "http://localhost:3000/users";
  List<dynamic> users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        setState(() {
          users = json.decode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> saveUser({
    Map? user,
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final body = jsonEncode({
        "name": name,
        "email": email,
        "password": password,
        "role": role,
      });

      if (user == null) {
        // ADD
        await http.post(
          Uri.parse(apiUrl),
          headers: {"Content-Type": "application/json"},
          body: body,
        );
      } else {
        // EDIT
        await http.put(
          Uri.parse("$apiUrl/${user['id']}"),
          headers: {"Content-Type": "application/json"},
          body: body,
        );
      }
      fetchUsers();
      Navigator.pop(context);
    } catch (e) {
      print("Error saving user: $e");
    }
  }

  Future<void> deleteUser(int id) async {
    await http.delete(Uri.parse("$apiUrl/$id"));
    fetchUsers();
  }

  void _showUserDialog({Map? user}) {
    final isEdit = user != null;
    final nameCtrl = TextEditingController(text: isEdit ? user['name'] : '');
    final emailCtrl = TextEditingController(text: isEdit ? user['email'] : '');
    final passCtrl = TextEditingController(
      text: isEdit ? user['password'] : '',
    );
    String selectedRole = isEdit ? user['role'] : 'user';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEdit ? "Edit User" : "Add User"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: "Name"),
                ),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: "Email"),
                ),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(labelText: "Password"),
                ),
                const SizedBox(height: 10),
                DropdownButton<String>(
                  value: selectedRole,
                  isExpanded: true,
                  items: ['user', 'admin'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (newValue) =>
                      setState(() => selectedRole = newValue!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (emailCtrl.text.isNotEmpty && passCtrl.text.isNotEmpty) {
                  saveUser(
                    user: user,
                    name: nameCtrl.text,
                    email: emailCtrl.text,
                    password: passCtrl.text,
                    role: selectedRole,
                  );
                }
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User Management")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: user['role'] == 'admin'
                        ? Colors.red
                        : Colors.blue,
                    child: Icon(
                      user['role'] == 'admin' ? Icons.security : Icons.person,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    user['name'] ?? user['email'],
                  ), // Show Name if available
                  subtitle: Text(
                    "${user['email']} • ${user['role'].toUpperCase()}",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showUserDialog(user: user),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => deleteUser(user['id']),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
