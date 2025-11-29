import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DealerContactScreen extends StatefulWidget {
  const DealerContactScreen({super.key});

  @override
  State<DealerContactScreen> createState() => _DealerContactScreenState();
}

class _DealerContactScreenState extends State<DealerContactScreen> {
  // Use a proper URL constant if available, otherwise localhost works for testing
  final String apiUrl = "http://localhost:3000/contacts";
  List<dynamic> contacts = [];
  bool isLoading = true;
  String userRole = 'user'; // Default role

  @override
  void initState() {
    super.initState();
    fetchContacts();
  }

  // --- API CALLS ---

  Future<void> fetchContacts() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        setState(() {
          contacts = json.decode(response.body);
          isLoading = false;
        });
      } else {
        // Handle server error response
        throw Exception('Failed to load contacts: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      // In a real app, you would show a snackbar or error message
      print('Error fetching contacts: $e');
    }
  }

  Future<void> saveContact({
    Map? contact,
    required String firstName,
    required String lastName,
    required String position, // NEW FIELD
    required String mobilePhone,
    required String officePhone,
    required String email,
    required String address,
  }) async {
    try {
      final body = jsonEncode({
        "first_name": firstName,
        "last_name": lastName,
        "position": position, // NEW FIELD SENT TO API
        "mobile_phone": mobilePhone,
        "office_phone": officePhone,
        "email": email,
        "address": address,
      });

      if (contact == null) {
        // ADD NEW CONTACT
        await http.post(
          Uri.parse(apiUrl),
          headers: {"Content-Type": "application/json"},
          body: body,
        );
      } else {
        // EDIT EXISTING CONTACT (Using salesperson_id for the PUT endpoint)
        final contactId = contact['salesperson_id'];
        await http.put(
          Uri.parse("$apiUrl/$contactId"),
          headers: {"Content-Type": "application/json"},
          body: body,
        );
      }

      // Refresh list and close dialog
      fetchContacts();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      print('Error saving contact: $e');
      // Show error to user
    }
  }

  Future<void> deleteContact(int id) async {
    try {
      // NOTE: We use the salesperson_id here.
      await http.delete(Uri.parse("$apiUrl/$id"));
      fetchContacts();
    } catch (e) {
      print('Error deleting contact: $e');
    }
  }

  // --- UI LOGIC ---

  void _showContactDialog({Map? contact}) {
    final isEdit = contact != null;

    // Split name fields for editing (if available)
    final firstName = isEdit ? contact['first_name'] : '';
    final lastName = isEdit ? contact['last_name'] : '';
    final position =
        isEdit ? contact['position'] : ''; // NEW: Initialize Position

    final firstNameCtrl = TextEditingController(text: firstName);
    final lastNameCtrl = TextEditingController(text: lastName);
    final positionCtrl =
        TextEditingController(text: position); // NEW: Position Controller
    final mobilePhoneCtrl =
        TextEditingController(text: isEdit ? contact['mobile_phone'] : '');
    final officePhoneCtrl =
        TextEditingController(text: isEdit ? contact['office_phone'] : '');
    final emailCtrl =
        TextEditingController(text: isEdit ? contact['email'] : '');
    final addressCtrl =
        TextEditingController(text: isEdit ? contact['address'] : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? "Edit Sales Contact" : "Add Sales Contact"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameCtrl,
                decoration: const InputDecoration(labelText: "First Name"),
              ),
              TextField(
                controller: lastNameCtrl,
                decoration: const InputDecoration(labelText: "Last Name"),
              ),
              TextField(
                controller: positionCtrl, // NEW: Position TextField
                decoration: const InputDecoration(labelText: "Position"),
              ),
              TextField(
                controller: mobilePhoneCtrl,
                decoration: const InputDecoration(labelText: "Mobile Phone"),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: officePhoneCtrl,
                decoration:
                    const InputDecoration(labelText: "Office Phone (Optional)"),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: addressCtrl,
                decoration:
                    const InputDecoration(labelText: "Address (Optional)"),
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
              firstName: firstNameCtrl.text,
              lastName: lastNameCtrl.text,
              position: positionCtrl.text, // NEW: Pass Position
              mobilePhone: mobilePhoneCtrl.text,
              officePhone: officePhoneCtrl.text,
              email: emailCtrl.text,
              address: addressCtrl.text,
            ),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Safely get user role from arguments
    userRole =
        (ModalRoute.of(context)?.settings.arguments as String?) ?? 'user';
    final isAdmin = userRole == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text("Dealer Contacts")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : contacts.isEmpty
              ? const Center(child: Text("No Sales Contacts Found"))
              : ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: contacts.length,
                  separatorBuilder: (ctx, i) => const Divider(),
                  itemBuilder: (context, index) {
                    final contact = contacts[index];

                    // Combine first and last name for display
                    final fullName =
                        "${contact['first_name']} ${contact['last_name']}"
                            .trim();
                    final initials =
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

                    // Get position, defaulting to 'Salesperson' if not present (requires backend update)
                    final position = contact['position'] ?? 'Salesperson';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.indigo,
                        child: Text(initials,
                            style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(
                        fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      // Display the position and email
                      subtitle: Text("${position}  \n${contact['email']}"),
                      trailing: isAdmin
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () =>
                                      _showContactDialog(contact: contact),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  // Use salesperson_id for deletion
                                  onPressed: () =>
                                      deleteContact(contact['salesperson_id']),
                                ),
                              ],
                            )
                          : Text(
                              // Display mobile phone for non-admin/non-sales users
                              contact['mobile_phone'] ?? 'N/A',
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
