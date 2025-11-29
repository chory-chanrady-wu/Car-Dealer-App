import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
// Import the existing detail screen (assumed to exist)
import 'car_detail_screen.dart';

class CarListScreen extends StatefulWidget {
  const CarListScreen({super.key});

  @override
  State<CarListScreen> createState() => _CarListScreenState();
}

// --- Mock User/Role Data for Testing RBAC ---
// These IDs must match existing user IDs in your 'users' table in MySQL
const Map<String, dynamic> mockUsers = {
  'User (Default)': {'id': 3, 'role': 'user'},
  'Salesperson': {
    'id': 2,
    'role': 'sale'
  }, // Must match a user with role 'sales'
  'Administrator': {
    'id': 1,
    'role': 'admin'
  }, // Must match a user with role 'admin'
};

class _CarListScreenState extends State<CarListScreen> {
  final String apiUrl = "http://localhost:3000/cars";
  List<dynamic> cars = [];
  bool isLoading = true;
  bool isError = false;

  // New state for simulating the current logged-in user
  String _selectedRoleKey = 'User (Default)';
  int _currentUserId = mockUsers['User (Default)']!['id'] as int;
  String _currentUserRole = mockUsers['User (Default)']!['role'] as String;

  // Global lists for dropdown options
  static const List<String> _engineTypes = [
    'Petrol',
    'Diesel',
    'Electric',
    'Hybrid'
  ];
  static const List<String> _carConditions = [
    'New',
    'Used',
    'Certified Pre-Owned'
  ];
  static const List<String> _carTypes = [
    'Sedan',
    'SUV',
    'Pick Up',
    'Hatchback',
    'Sports',
    'Minivan',
    'Coupe'
  ];

  @override
  void initState() {
    super.initState();
    fetchCars();
  }

  // --- Utility Functions ---

  bool get _isAuthorized =>
      _currentUserRole == 'admin' || _currentUserRole == 'sale';

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

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  // --- Networking Functions ---

  Future<void> fetchCars() async {
    setState(() {
      isLoading = true;
      isError = false;
    });
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        setState(() {
          // Cars are fetched, but we enforce sorting client-side for better UX
          cars = json.decode(response.body);
          // Sort available cars first, then sold cars
          cars.sort((a, b) {
            final statusA = a['status'] == 'Available' ? 0 : 1;
            final statusB = b['status'] == 'Available' ? 0 : 1;
            return statusA.compareTo(statusB);
          });
          isLoading = false;
        });
      } else {
        _showFeedback("Failed to load car list: Status ${response.statusCode}",
            isError: true);
        setState(() {
          isLoading = false;
          isError = true;
        });
      }
    } catch (e) {
      _showFeedback("Network error fetching car list: $e", isError: true);
      setState(() {
        isLoading = false;
        isError = true;
      });
    }
  }

  Future<void> _addCar(Map<String, dynamic> carData) async {
    // Add the current user's ID for authorization on the backend
    carData['salesperson_id'] = _currentUserId;

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(carData),
      );

      if (response.statusCode == 200) {
        _showFeedback("Car added successfully!");
        fetchCars();
      } else {
        final errorBody = json.decode(response.body);
        _showFeedback(
            "Failed to add car: ${errorBody['error'] ?? response.statusCode}",
            isError: true);
      }
    } catch (e) {
      _showFeedback("Network error adding car: $e", isError: true);
    }
  }

  Future<void> _sellCar(int carId, double soldPrice) async {
    final sellUrl = "$apiUrl/$carId/sell";
    final payload = {
      'sold_price': soldPrice,
      'salesperson_id': _currentUserId, // Required for backend RBAC
    };

    try {
      final response = await http.post(
        Uri.parse(sellUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        _showFeedback("Car #$carId marked as SOLD!");
        fetchCars();
      } else {
        final errorBody = json.decode(response.body);
        _showFeedback(
            "Failed to sell car: ${errorBody['error'] ?? response.statusCode}",
            isError: true);
      }
    } catch (e) {
      _showFeedback("Network error selling car: $e", isError: true);
    }
  }

  // New: Function to delete a car (Admin only on backend)
  Future<void> _deleteCar(int carId) async {
    final deleteUrl = "$apiUrl/$carId";

    try {
      // Send the user ID in the headers or query if the backend needs it for RBAC,
      // but for simplicity, we rely on the URL and client-side role check here.
      final response = await http.delete(Uri.parse(deleteUrl));

      if (response.statusCode == 200) {
        _showFeedback("Car #$carId deleted successfully!",
            isError: true); // Use error style for destructive action feedback
        fetchCars();
      } else {
        final errorBody = json.decode(response.body);
        _showFeedback(
            "Failed to delete car: ${errorBody['error'] ?? response.statusCode}",
            isError: true);
      }
    } catch (e) {
      _showFeedback("Network error deleting car: $e", isError: true);
    }
  }

  // --- UI Dialogs ---

  // Helper for Dropdowns
  Widget _buildDropdownField({
    required String label,
    required List<String> options,
    required String currentValue,
    required Function(String) onUpdate,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8))),
        ),
        isExpanded: true,
        items: options.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: (newValue) {
          if (newValue != null) {
            onUpdate(newValue);
          }
        },
        validator: (v) => v == null || v!.isEmpty ? "$label is required" : null,
        onSaved: (v) => onUpdate(v!),
      ),
    );
  }

  void _showAddCarDialog() {
    final formKey = GlobalKey<FormState>();
    final carData = {
      'make': '',
      'model': '',
      'year': '',
      'price': '',
      'import_price': '',
      // Default values for new detail fields
      'color': 'White',
      'engine_type': _engineTypes.first,
      'car_condition': _carConditions.first,
      'car_type': _carTypes.first,
      'description': '',
      'remark': '', // Optional, starting empty
    };

    showDialog(
      context: context,
      builder: (context) {
        // Use StatefulBuilder to manage the internal state of the dialog (like dropdown selections)
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add New Car to Inventory'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Basic Info
                      _buildTextField('Make', (v) => carData['make'] = v!,
                          isNumber: false),
                      _buildTextField('Model', (v) => carData['model'] = v!,
                          isNumber: false),
                      _buildTextField('Year', (v) => carData['year'] = v!,
                          isNumber: true),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(color: Colors.indigo),
                      ),

                      // Detailed Specs
                      _buildTextField('Color', (v) => carData['color'] = v!,
                          isNumber: false),

                      _buildDropdownField(
                        label: 'Engine Type',
                        options: _engineTypes,
                        currentValue: carData['engine_type'] as String,
                        onUpdate: (newValue) =>
                            setState(() => carData['engine_type'] = newValue),
                      ),

                      _buildDropdownField(
                        label: 'Car Condition',
                        options: _carConditions,
                        currentValue: carData['car_condition'] as String,
                        onUpdate: (newValue) =>
                            setState(() => carData['car_condition'] = newValue),
                      ),

                      _buildDropdownField(
                        label: 'Car Type',
                        options: _carTypes,
                        currentValue: carData['car_type'] as String,
                        onUpdate: (newValue) =>
                            setState(() => carData['car_type'] = newValue),
                      ),

                      // Prices
                      _buildTextField('Import Price (\$)',
                          (v) => carData['import_price'] = v!,
                          isNumber: true),
                      _buildTextField(
                          'Asking Price (\$)', (v) => carData['price'] = v!,
                          isNumber: true),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(color: Colors.indigo),
                      ),

                      // Description & Remark
                      _buildTextField(
                        'Description',
                        (v) => carData['description'] = v!,
                        isNumber: false,
                        maxLines: 4,
                      ),
                      _buildTextField(
                        'Remark (Optional Notes)',
                        (v) => carData['remark'] = v!,
                        isNumber: false,
                        isOptional: true, // Allow this field to be empty
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();
                      Navigator.pop(context); // Close dialog

                      // Data is converted to correct types before sending
                      await _addCar({
                        'make': carData['make'],
                        'model': carData['model'],
                        'year': int.parse(carData['year']!),
                        'price': double.parse(carData['price']!),
                        'import_price': double.parse(carData['import_price']!),
                        'color': carData['color'],
                        'engine_type': carData['engine_type'],
                        'car_condition': carData['car_condition'],
                        'car_type': carData['car_type'],
                        'description': carData['description'],
                        'remark': carData['remark'],
                      });
                    }
                  },
                  child: const Text('Add Car'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTextField(String label, FormFieldSetter<String> onSaved,
      {bool isNumber = false, bool isOptional = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8))),
          hintText: label,
        ),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        validator: (value) {
          if (!isOptional && (value == null || value.isEmpty)) {
            return 'Please enter $label';
          }
          if (isNumber &&
              (value!.isNotEmpty && double.tryParse(value) == null)) {
            return 'Must be a valid number';
          }
          return null;
        },
        onSaved: onSaved,
      ),
    );
  }

  void _showSellCarDialog(Map<String, dynamic> car) {
    double soldPrice = double.tryParse(car['price']?.toString() ?? '0') ?? 0;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Sell ${car['make']} ${car['model']}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Current Asking Price: ${_formatCurrency(soldPrice)}"),
                Text(
                    "Import Cost: ${_formatCurrency(double.tryParse(car['import_price']?.toString() ?? '0') ?? 0)}"),
                const SizedBox(height: 15),
                TextFormField(
                  initialValue: soldPrice.toStringAsFixed(0),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Final Sold Price (\$)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || double.tryParse(value) == null) {
                      return 'Enter a valid price';
                    }
                    return null;
                  },
                  onSaved: (value) => soldPrice = double.parse(value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  Navigator.pop(context);
                  await _sellCar(car['id'] as int, soldPrice);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Mark as Sold',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // New: Confirmation dialog for car deletion
  void _showDeleteConfirmationDialog(Map<String, dynamic> car) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
              'Are you sure you want to permanently delete ${car['make']} ${car['model']} (ID: ${car['id']})? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                await _deleteCar(car['id'] as int);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- Widget Builders ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cars Listing'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // Role Selector (simulates user login)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButton<String>(
              value: _selectedRoleKey,
              dropdownColor: Colors.indigo,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              underline: Container(), // Removes the default underline
              items: mockUsers.keys.map((String key) {
                return DropdownMenuItem<String>(
                  value: key,
                  child: Text(
                    key,
                    style: TextStyle(
                      color: key == _selectedRoleKey
                          ? Colors.lightGreenAccent
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedRoleKey = newValue;
                    _currentUserId = mockUsers[newValue]!['id'] as int;
                    _currentUserRole = mockUsers[newValue]!['role'] as String;
                  });
                  _showFeedback(
                      "Switched to role: $_currentUserRole (ID: $_currentUserId)");
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchCars,
            tooltip: 'Refresh List',
          ),
        ],
      ),
      body: _buildBody(),
      // Floating Action Button for adding cars, only visible for authorized users
      floatingActionButton: _isAuthorized
          ? FloatingActionButton.extended(
              onPressed: _showAddCarDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Car'),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            )
          : null,
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
            const Text("Failed to load inventory. Check server status."),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: fetchCars,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    if (cars.isEmpty) {
      return const Center(child: Text("No cars found in inventory."));
    }

    return ListView.builder(
      itemCount: cars.length,
      itemBuilder: (context, index) {
        final car = cars[index];
        final bool isSold = car['status'] == 'sold';
        final double price =
            double.tryParse(car['price']?.toString() ?? '0') ?? 0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSold
                ? BorderSide(color: Colors.red.shade300, width: 2)
                : BorderSide.none,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: const SizedBox(
              width: 60,
              height: 60,
              child: Icon(Icons.directions_car_filled,
                  size: 40, color: Colors.indigo),
            ),
            title: Text(
              "${car['year'] ?? ''} ${car['make'] ?? ''} ${car['model'] ?? ''}",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSold ? Colors.grey[700] : Colors.black87),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSold ? "Status: SOLD" : "Status: Available",
                  style: TextStyle(
                    color: isSold ? Colors.red.shade700 : Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "Listing ID: ${car['id']}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // New: Delete Button (Admin only, available cars only)
                if (_currentUserRole == 'admin')
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _showDeleteConfirmationDialog(car),
                    tooltip: 'Delete Car',
                  ),

                // Sell Button (Only visible for authorized users and available cars)
                if (_isAuthorized && !isSold)
                  SizedBox(
                    width: 80,
                    child: ElevatedButton(
                      onPressed: () => _showSellCarDialog(car),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                      ),
                      child: const Text('Sell',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                  )
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCurrency(price),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo),
                      ),
                      if (isSold)
                        const Text("View Details",
                            style: TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                  ),
                const Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey),
              ],
            ),
            onTap: () => _navigateToDetail(car['id']),
          ),
        );
      },
    );
  }

  // Handles navigation to the detail screen
  void _navigateToDetail(int carId) async {
    // Navigate and wait for the result. The detail screen returns 'true' if the car was deleted/edited.
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarDetailScreen(
          carId: carId,
          // Note: Detail screen needs logic to show edit/delete based on this role
          isAdmin: _currentUserRole == 'admin',
        ),
      ),
    );

    // If the detail screen signaled a change (e.g., car deleted or updated), refresh the list.
    if (result == true) {
      fetchCars();
      _showFeedback("Car list refreshed.");
    }
  }
}
