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
  bool isError = false;

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  // Helper function to show persistent feedback (Snackbars)
  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- API Handlers ---

  Future<void> fetchUsers() async {
    setState(() {
      isLoading = true;
      isError = false;
    });
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        setState(() {
          users = json.decode(response.body);
          isLoading = false;
        });
        // Sort users by role: admin first, then sales, then user
        users.sort((a, b) {
          final roleOrder = {'admin': 1, 'sales': 2, 'user': 3};
          return (roleOrder[a['role']] ?? 9)
              .compareTo(roleOrder[b['role']] ?? 9);
        });
      } else {
        _showFeedback("Failed to load users: Status ${response.statusCode}",
            isError: true);
        setState(() {
          isLoading = false;
          isError = true;
        });
      }
    } catch (e) {
      _showFeedback("Network error fetching users: $e", isError: true);
      setState(() {
        isLoading = false;
        isError = true;
      });
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
        // CRUCIAL: Only include the password field in the body if the user has typed something (i.e., password is not an empty string).
        // This prevents updating the password to NULL or an empty string, or causing a backend validation error on edit.
        if (password.isNotEmpty) "password": password,
        "role": role,
      });

      http.Response response;
      if (user == null) {
        // ADD (POST)
        response = await http.post(
          Uri.parse(apiUrl),
          headers: {"Content-Type": "application/json"},
          body: body,
        );
      } else {
        // EDIT (PUT)
        response = await http.put(
          Uri.parse("$apiUrl/${user['id']}"),
          headers: {"Content-Type": "application/json"},
          body: body,
        );
      }

      if (response.statusCode == 200) {
        _showFeedback(
            "User ${user == null ? 'added' : 'updated'} successfully!");
        fetchUsers();
        // Pop the dialog after successful operation
        if (mounted) Navigator.pop(context);
      } else {
        final errorBody = json.decode(response.body);
        _showFeedback(
            "Failed to save user: ${errorBody['error'] ?? response.statusCode}",
            isError: true);
      }
    } catch (e) {
      _showFeedback("Network error saving user: $e", isError: true);
    }
  }

  Future<void> deleteUser(int id) async {
    try {
      final response = await http.delete(Uri.parse("$apiUrl/$id"));
      if (response.statusCode == 200) {
        _showFeedback("User ID $id deleted successfully.");
        fetchUsers();
      } else {
        final errorBody = json.decode(response.body);
        _showFeedback(
            "Failed to delete user: ${errorBody['error'] ?? response.statusCode}",
            isError: true);
      }
    } catch (e) {
      _showFeedback("Network error deleting user: $e", isError: true);
    }
  }

  // --- UI Dialogs ---
  void _showUserDialog({Map? user}) {
    final isEdit = user != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: isEdit ? user['name'] : '');
    final emailCtrl = TextEditingController(text: isEdit ? user['email'] : '');

    // AS REQUESTED: Pre-filling the password field with the existing password.
    // NOTE: In a production app, this would be empty to prevent exposing sensitive data.
    final passCtrl =
        TextEditingController(text: isEdit ? user['password'] : '');

    String selectedRole = isEdit ? user['role'] : 'user';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title:
              Text(isEdit ? "Edit User (ID: ${user['id']})" : "Add New User"),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: "Name"),
                    validator: (v) => v!.isEmpty ? "Name is required" : null,
                  ),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: "Email"),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.isEmpty ? "Email is required" : null,
                  ),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                        labelText: isEdit
                            ? "New Password (Leave blank to keep old)"
                            : "Password"),
                    // On Edit, the password field is optional. On Add, it is required.
                    validator: (v) => isEdit
                        ? null
                        : (v!.isEmpty
                            ? "Password is required for new users"
                            : null),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: "User Role",
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: ['user', 'sales', 'admin'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (newValue) =>
                        setState(() => selectedRole = newValue!),
                    validator: (v) => v == null ? "Role is required" : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  saveUser(
                    user: user,
                    name: nameCtrl.text,
                    email: emailCtrl.text,
                    // Pass the current text. If blank, saveUser omits it from the API call body.
                    password: passCtrl.text,
                    role: selectedRole,
                  );
                  // Dialog dismissal is handled by saveUser on success
                }
              },
              child: Text(isEdit ? "Update" : "Add"),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widget Builders ---

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red.shade700;
      case 'sales':
        return Colors.indigo.shade500;
      default:
        return Colors.green.shade600;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.verified_user;
      case 'sales':
        return Icons.work;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Management"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchUsers,
            tooltip: 'Refresh List',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 50, color: Colors.grey),
            const SizedBox(height: 10),
            const Text("Failed to load user list. Check server status."),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: fetchUsers,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final String role = user['role'] ?? 'user';
        final Color roleColor = _getRoleColor(role);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: roleColor,
              child: Icon(
                _getRoleIcon(role),
                color: Colors.white,
              ),
            ),
            title: Text(
              user['name'] ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "${user['email']} • ${role.toUpperCase()} (ID: ${user['id']})",
              style: TextStyle(color: roleColor.withOpacity(0.8), fontSize: 13),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showUserDialog(user: user),
                  tooltip: 'Edit User',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => deleteUser(user['id']),
                  tooltip: 'Delete User',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
