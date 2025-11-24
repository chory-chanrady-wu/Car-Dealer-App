import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CarDetailScreen extends StatefulWidget {
  final int carId;
  final bool isAdmin;

  const CarDetailScreen(
      {super.key, required this.carId, required this.isAdmin});

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  final String apiUrl = "http://localhost:3000/cars";
  Map<String, dynamic>? car;
  bool isLoading = true;
  bool isError = false;

  @override
  void initState() {
    super.initState();
    fetchCarDetails();
  }

  // Helper function to show persistent feedback
  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> fetchCarDetails() async {
    setState(() {
      isLoading = true;
      isError = false;
    });
    try {
      final response = await http.get(Uri.parse('$apiUrl/${widget.carId}'));

      if (response.statusCode == 200) {
        setState(() {
          car = json.decode(response.body);
          isLoading = false;
        });
      } else {
        _showFeedback("Failed to load details: ${response.statusCode}",
            isError: true);
        setState(() {
          isLoading = false;
          isError = true;
        });
      }
    } catch (e) {
      _showFeedback("Network error fetching details: $e", isError: true);
      setState(() {
        isLoading = false;
        isError = true;
      });
    }
  }

  // --- DELETE CAR ---
  Future<void> deleteCar() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text("Confirm Deletion"),
              content: Text(
                  "Are you sure you want to delete ${car!['brand']} ${car!['model']}?"),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancel")),
                ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white),
                    child: const Text("Delete")),
              ],
            ));

    if (confirmed == true) {
      try {
        final response =
            await http.delete(Uri.parse("$apiUrl/${widget.carId}"));
        if (response.statusCode == 200 || response.statusCode == 204) {
          _showFeedback("Car deleted successfully!");
          if (mounted) {
            // Pop back to the list screen
            Navigator.pop(context, true);
          }
        } else {
          _showFeedback("Failed to delete car: ${response.statusCode}",
              isError: true);
        }
      } catch (e) {
        _showFeedback("Network Error during delete: $e", isError: true);
      }
    }
  }

  // --- EDIT DIALOG AND FUNCTIONALITY ---
  void _showEditCarDialog() {
    if (car == null) return;

    final brandCtrl = TextEditingController(text: car!['brand']?.toString());
    final modelCtrl = TextEditingController(text: car!['model']?.toString());
    final yearCtrl =
        TextEditingController(text: car!['year']?.toString() ?? '0');
    final importCtrl = TextEditingController(text: car!['import_price']);
    final priceCtrl = TextEditingController(text: car!['price']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Vehicle Details"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: brandCtrl,
                  decoration: const InputDecoration(labelText: "Brand")),
              TextField(
                  controller: modelCtrl,
                  decoration: const InputDecoration(labelText: "Model")),
              TextField(
                  controller: yearCtrl,
                  decoration: const InputDecoration(labelText: "Year"),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: importCtrl,
                  decoration:
                      const InputDecoration(labelText: "Import Price (Cost)"),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(labelText: "Listing Price"),
                  keyboardType: TextInputType.number),
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  "*Images can only be modified in the 'Add New' flow for simplicity.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => _updateCar(brandCtrl.text, modelCtrl.text,
                yearCtrl.text, importCtrl.text, priceCtrl.text),
            child: const Text("Save Changes"),
          ),
        ],
      ),
    );
  }

  Future<void> _updateCar(String brand, String model, String year,
      String importPrice, String price) async {
    try {
      final response = await http.put(
        Uri.parse('$apiUrl/${widget.carId}'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "brand": brand,
          "model": model,
          "year": int.tryParse(year) ?? 0,
          "import_price": double.tryParse(importPrice) ?? 0.0,
          "price": double.tryParse(price) ?? 0.0,
          // Note: Images are excluded from the basic edit flow
        }),
      );

      if (response.statusCode == 200) {
        _showFeedback("Car updated successfully!");
        fetchCarDetails(); // Refresh data
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['details'] ?? 'Unknown error';
        _showFeedback(
            "Failed to update car (Code ${response.statusCode}): $errorMessage",
            isError: true);
      }
    } catch (e) {
      _showFeedback("Network/Server Error during update: $e", isError: true);
    }

    if (mounted) Navigator.pop(context); // Close dialog
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(car == null
            ? 'Car Details'
            : '${car!['brand'] ?? ''} ${car!['model'] ?? ''}'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: widget.isAdmin && car != null
            ? [
                IconButton(
                    onPressed: _showEditCarDialog,
                    icon: const Icon(Icons.edit)),
                IconButton(
                    onPressed: deleteCar, icon: const Icon(Icons.delete)),
              ]
            : null,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : isError
              ? Center(
                  child:
                      Text("Error loading car details for ID: ${widget.carId}"))
              : car == null
                  ? const Center(child: Text("Car not found."))
                  : _buildCarDetails(),
    );
  }

  Widget _buildCarDetails() {
    final List<String> images =
        (car!['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
            [];
    final isSold = car!['status'] == 'sold';
    final soldPrice = car!['sold_price'] ?? 0.0;
    final importPrice = car!['import_price'] ?? 0.0;
    final profit = isSold ? (soldPrice - importPrice) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Image Gallery ---
          if (images.isNotEmpty)
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  try {
                    Uint8List bytes = base64Decode(images[index]);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          bytes,
                          width: 280,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            width: 280,
                            color: Colors.red[100],
                            child: const Center(
                                child: Text("Image Load Error",
                                    style: TextStyle(color: Colors.red))),
                          ),
                        ),
                      ),
                    );
                  } catch (e) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Container(
                        width: 280,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(child: Icon(Icons.broken_image)),
                      ),
                    );
                  }
                },
              ),
            )
          else
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car, size: 40, color: Colors.grey),
                  Text("No Images Available"),
                ],
              )),
            ),

          const SizedBox(height: 20),

          // --- Status Badge ---
          Chip(
            label: Text(
              isSold ? 'SOLD' : 'AVAILABLE',
              style: TextStyle(
                  color: isSold ? Colors.white : Colors.indigo,
                  fontWeight: FontWeight.bold),
            ),
            backgroundColor:
                isSold ? Colors.red.shade700 : Colors.indigo.shade100,
          ),
          const SizedBox(height: 10),

          // --- General Details ---
          _buildInfoTile('Brand', car!['brand']),
          _buildInfoTile('Model', car!['model']),
          _buildInfoTile('Year', car!['year'].toString()),
          _buildInfoTile('Vehicle ID', car!['id'].toString()),

          const Divider(height: 30),

          // --- Financial Details ---
          Text('Financial Information',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700])),
          const SizedBox(height: 10),

          // Listing Price
          _buildInfoTile(
              'Listing Price', '\$${car!['price']}',
              color: Colors.green.shade700, fontWeight: FontWeight.bold),

          // Import Price (Admin Only)
          if (widget.isAdmin)
            _buildInfoTile(
                'Import Price (Cost)', '\$${importPrice}',
                color: Colors.grey[700]),

          // Sold Status and Profit
          if (isSold) ...[
            _buildInfoTile('Sold Price', '\$${soldPrice}',
                color: Colors.red.shade700, fontWeight: FontWeight.bold),
            if (widget.isAdmin)
              _buildInfoTile('Profit/Loss', '\$${profit}',
                  color:
                      profit > 0 ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.bold),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value,
      {Color? color, FontWeight fontWeight = FontWeight.normal}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          Text(
            value,
            style:
                TextStyle(fontSize: 16, color: color, fontWeight: fontWeight),
          ),
        ],
      ),
    );
  }
}
