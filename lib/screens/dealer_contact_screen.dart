import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DealerContactScreen extends StatefulWidget {
  const DealerContactScreen({super.key});

  @override
  State<DealerContactScreen> createState() => _DealerContactScreenState();
}

class _DealerContactScreenState extends State<DealerContactScreen> {
  final String apiUrl = "http://localhost:3000/contacts";
  List<dynamic> contacts = [];
  bool isLoading = true;
  String userRole = 'user';

  @override
  void initState() {
    super.initState();
    fetchContacts();
  }

  Future<void> fetchContacts() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        setState(() {
          contacts = json.decode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> saveContact({
    Map? contact,
    required String name,
    required String role,
    required String phone,
    required String email,
  }) async {
    try {
      final body = jsonEncode({
        "name": name,
        "role": role,
        "phone": phone,
        "email": email,
      });
      if (contact == null) {
        await http.post(
          Uri.parse(apiUrl),
          headers: {"Content-Type": "application/json"},
          body: body,
        );
      } else {
        await http.put(
          Uri.parse("$apiUrl/${contact['id']}"),
          headers: {"Content-Type": "application/json"},
          body: body,
        );
      }
      fetchContacts();
      Navigator.pop(context);
    } catch (e) {
      print(e);
    }
  }

  Future<void> deleteContact(int id) async {
    await http.delete(Uri.parse("$apiUrl/$id"));
    fetchContacts();
  }

  void _showContactDialog({Map? contact}) {
    final isEdit = contact != null;
    final nameCtrl = TextEditingController(text: isEdit ? contact['name'] : '');
    final roleCtrl = TextEditingController(text: isEdit ? contact['role'] : '');
    final phoneCtrl = TextEditingController(
      text: isEdit ? contact['phone'] : '',
    );
    final emailCtrl = TextEditingController(
      text: isEdit ? contact['email'] : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? "Edit Contact" : "Add Contact"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(
                  labelText: "Role (e.g. Mechanic)",
                ),
              ),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: "Phone"),
              ),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: "Email"),
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
            onPressed: () => saveContact(
              contact: contact,
              name: nameCtrl.text,
              role: roleCtrl.text,
              phone: phoneCtrl.text,
              email: emailCtrl.text,
            ),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    userRole = ModalRoute.of(context)!.settings.arguments as String? ?? 'user';
    final isAdmin = userRole == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text("Dealer Contacts")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(10),
              itemCount: contacts.length,
              separatorBuilder: (ctx, i) => const Divider(),
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Text(contact['name'][0]),
                  ),
                  title: Text(
                    contact['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("${contact['role']} • ${contact['email']}"),
                  trailing: isAdmin
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () =>
                                  _showContactDialog(contact: contact),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteContact(contact['id']),
                            ),
                          ],
                        )
                      : Text(
                          contact['phone'],
                          style: const TextStyle(
                            color: Colors.indigo,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                );
              },
            ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showContactDialog(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
