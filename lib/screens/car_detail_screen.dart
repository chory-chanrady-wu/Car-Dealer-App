import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// Helper widget to display specification rows.
class _DetailTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailTile(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.indigo.shade600, size: 24),
          const SizedBox(width: 10),
          Expanded(
            // Use Expanded to prevent overflow on long values
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CarDetailScreen extends StatefulWidget {
  final int carId;
  final bool isAdmin;

  const CarDetailScreen(
      {super.key, required this.carId, required this.isAdmin});

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  // Use NumberFormat for currency formatting
  final currencyFormatter =
      NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final dateFormatter = DateFormat('MMM dd, yyyy');

  // NOTE: This URL is for development/testing environments and should be replaced
  // with a valid network address if running on a real device or outside of a
  // simulated environment like a web browser's localhost.
  final String apiUrl = "http://localhost:3000/cars";
  Map<String, dynamic>? car;
  bool isLoading = true;
  bool isError = false;

  @override
  void initState() {
    super.initState();
    fetchCarDetails();
  }

  /// Helper function to show persistent feedback using a SnackBar.
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

  /// Fetches car data from the API endpoint.
  Future<void> fetchCarDetails() async {
    setState(() {
      isLoading = true;
      isError = false;
    });
    try {
      final response = await http.get(Uri.parse("$apiUrl/${widget.carId}"));
      if (response.statusCode == 200) {
        setState(() {
          // The response now contains the new structure
          car = json.decode(response.body);
          isLoading = false;
        });
      } else {
        _showFeedback("Failed to load details: Status ${response.statusCode}",
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

  /// Handles the deletion of the current car record.
  Future<void> deleteCar() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text("Confirm Deletion"),
              content: Text(
                  "Are you sure you want to delete ${car!['make']} ${car!['model']}? This cannot be undone."),
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
            Navigator.pop(context, true); // Pop back to the list screen
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

  /// Shows a dialog for editing car details.
  void _showEditCarDialog() {
    if (car == null) return;

    // Initialize controllers with current values, providing defaults
    final makeCtrl =
        TextEditingController(text: car!['make']?.toString() ?? '');
    final modelCtrl =
        TextEditingController(text: car!['model']?.toString() ?? '');
    final yearCtrl =
        TextEditingController(text: car!['year']?.toString() ?? '');
    final importCtrl =
        TextEditingController(text: car!['import_price']?.toString() ?? '0.00');
    final priceCtrl =
        TextEditingController(text: car!['price']?.toString() ?? '0.00');
    final soldPriceCtrl =
        TextEditingController(text: car!['sold_price']?.toString() ?? '0.00');
    final colorCtrl =
        TextEditingController(text: car!['color']?.toString() ?? '');
    final descriptionCtrl =
        TextEditingController(text: car!['description']?.toString() ?? '');

    // UPDATED CONTROLLERS
    final vinNumberCtrl =
        TextEditingController(text: car!['vin_number']?.toString() ?? '');
    final carConditionCtrl =
        TextEditingController(text: car!['car_condition']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Vehicle Details"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Basic Info
              TextField(
                  controller: makeCtrl,
                  decoration: const InputDecoration(labelText: "Make")),
              TextField(
                  controller: modelCtrl,
                  decoration: const InputDecoration(labelText: "Model")),
              TextField(
                  controller: yearCtrl,
                  decoration: const InputDecoration(labelText: "Year"),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: colorCtrl,
                  decoration: const InputDecoration(labelText: "Color")),

              // New Technical Details
              TextField(
                  controller: vinNumberCtrl,
                  decoration: const InputDecoration(labelText: "VIN Number")),
              TextField(
                  controller: carConditionCtrl,
                  decoration: const InputDecoration(
                      labelText: "Car Condition (e.g., New/Used - Excellent)")),

              // Description
              TextField(
                  controller: descriptionCtrl,
                  decoration: const InputDecoration(labelText: "Description"),
                  maxLines: 3),
              const Divider(),

              // Financials
              TextField(
                  controller: importCtrl,
                  decoration:
                      const InputDecoration(labelText: "Import Price (Cost)"),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true)),
              TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(labelText: "Listing Price"),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true)),
              TextField(
                  controller: soldPriceCtrl,
                  decoration: const InputDecoration(
                      labelText: "Sold Price (Set to 0 if not sold)"),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true)),
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  "Note: Editing images requires a separate process.",
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
            onPressed: () => _updateCar(
              makeCtrl.text,
              modelCtrl.text,
              yearCtrl.text,
              importCtrl.text,
              priceCtrl.text,
              soldPriceCtrl.text,
              colorCtrl.text,
              descriptionCtrl.text,
              vinNumberCtrl.text,
              carConditionCtrl.text,
            ),
            child: const Text("Save Changes"),
          ),
        ],
      ),
    );
  }

  /// Sends a PUT request to update the car details.
  Future<void> _updateCar(
    String make,
    String model,
    String year,
    String importPrice,
    String price,
    String soldPrice,
    String color,
    String description,
    String vinNumber, // UPDATED
    String carCondition, // UPDATED
  ) async {
    Navigator.pop(context); // Close dialog immediately

    final double finalSoldPrice = double.tryParse(soldPrice) ?? 0.0;
    final String status = finalSoldPrice > 0 ? 'sold' : 'available';

    try {
      final response = await http.put(
        Uri.parse('$apiUrl/${widget.carId}'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "make": make,
          "model": model,
          "year": int.tryParse(year) ?? 0,
          "import_price": double.tryParse(importPrice) ?? 0.0,
          "price": double.tryParse(price) ?? 0.0,
          "sold_price": finalSoldPrice,
          "status": status,
          "color": color,
          "description": description,
          // UPDATED FIELDS
          "vin_number": vinNumber,
          "car_condition": carCondition,
          // Note: profit and sold_at are typically calculated server-side,
          // but we can manually set the status.
        }),
      );

      if (response.statusCode == 200) {
        _showFeedback("Car updated successfully!");
        fetchCarDetails(); // Refresh data
      } else {
        // Attempt to parse API error message
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['message'] ?? 'Unknown error';
        _showFeedback(
            "Failed to update car (Code ${response.statusCode}): $errorMessage",
            isError: true);
      }
    } catch (e) {
      _showFeedback("Network/Server Error during update: $e", isError: true);
    }
  }

  /// Widget to display financial summary row.
  Widget _buildFinanceRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 16, color: Colors.black87)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Handle error state
    if (isError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 10),
                Text("Could not load details for Car ID: ${widget.carId}",
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: fetchCarDetails,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry"),
                )
              ],
            ),
          ),
        ),
      );
    }

    // Handle null car (e.g., 404 response that didn't set isError)
    if (car == null)
      return const Scaffold(body: Center(child: Text("Car not found")));

    final List<dynamic> images = car!['images'] ?? [];

    // Extract and safely parse specification data
    final int year = car!['year'] ?? 0;
    final String color = car!['color'] ?? 'N/A';
    final String description =
        car!['description'] ?? 'No additional description provided.';
    final String status = car!['status'] ?? 'available';

    // UPDATED FIELDS
    final String vinNumber = car!['vin_number'] ?? 'N/A';
    final String carCondition = car!['car_condition'] ?? 'N/A';

    // --- SAFELY PARSE DATE ---
    final String soldAtString = car!['sold_at']?.toString() ?? '';
    String soldAtDisplay = 'N/A';
    if (soldAtString.isNotEmpty) {
      try {
        final soldAtDate = DateTime.parse(soldAtString);
        soldAtDisplay = dateFormatter.format(soldAtDate);
      } catch (e) {
        // Log or handle the error if the date string is malformed
        debugPrint('Error parsing sold_at date: $e');
        // Keep soldAtDisplay as 'N/A'
      }
    }

    // --- SAFELY PARSE FINANCIALS ---
    // Use the null-aware operator to safely access fields and fall back to '0' string
    final double importPrice =
        double.tryParse(car!['import_price']?.toString() ?? '0') ?? 0;
    final double finalSoldPrice =
        double.tryParse(car!['sold_price']?.toString() ?? '0') ?? 0;
    final double listingPrice =
        double.tryParse(car!['price']?.toString() ?? '0') ?? 0;
    // Use the profit field directly from the API response (safer access)
    final double profit = double.tryParse(car!['profit']?.toString() ?? '0') ??
        finalSoldPrice - importPrice; // Fallback calculation

    final Color statusColor = status == 'sold'
        ? Colors.red.shade700
        : (status == 'pending'
            ? Colors.orange.shade700
            : Colors.green.shade700);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            "${car!['year'] ?? ''} ${car!['make'] ?? ''} ${car!['model'] ?? ''}"),
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- IMAGE CAROUSEL ---
            Container(
              height: 250,
              color: Colors.grey[300],
              child: images.isEmpty
                  ? Center(
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_car,
                            size: 80, color: Colors.grey.shade600),
                        const SizedBox(height: 10),
                        const Text("No Images Available",
                            style: TextStyle(color: Colors.grey))
                      ],
                    ))
                  : PageView.builder(
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        try {
                          // Note: Assuming images are base64 encoded strings
                          return Image.memory(
                            base64Decode(images[index]),
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) =>
                                const Icon(Icons.broken_image),
                          );
                        } catch (e) {
                          // Handle malformed base64 strings
                          return Container(
                            color: Colors.red[100],
                            child: const Center(
                                child: Text("Image Decode Error",
                                    style: TextStyle(color: Colors.red))),
                          );
                        }
                      },
                    ),
            ),
            if (images.length > 1)
              Center(
                  child: Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Text("Swipe for more photos (${images.length})"),
              )),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER INFO & STATUS ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        status.toString(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        currencyFormatter.format(listingPrice),
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo),
                      ),
                    ],
                  ),
                  const Divider(height: 30),

                  // --- KEY SPECIFICATIONS (Visible to all) ---
                  const Text("Key Specifications",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo)),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.8,
                    children: [
                      _DetailTile(
                          label: "Year",
                          value: year.toString(),
                          icon: Icons.calendar_today),
                      _DetailTile(
                          label: "Condition",
                          value: carCondition, // UPDATED
                          icon: Icons.star_half),
                      _DetailTile(
                          label: "Color", value: color, icon: Icons.color_lens),
                      _DetailTile(
                          label: "VIN Number",
                          value: vinNumber, // UPDATED
                          icon: Icons.no_encryption),
                      _DetailTile(
                          label: "Inventory ID",
                          value: widget.carId.toString(),
                          icon: Icons.fingerprint),
                    ],
                  ),
                  const Divider(height: 30),

                  // --- DESCRIPTION ---
                  const Text("Description",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo)),
                  const SizedBox(height: 10),
                  Text(
                    description.isEmpty
                        ? 'The dealer has not yet provided a detailed description for this vehicle.'
                        : description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const Divider(height: 30),

                  // --- FINANCIAL DETAILS (Admin Only) ---
                  if (widget.isAdmin) ...[
                    const Text("Financials (Admin View)",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo)),
                    const SizedBox(height: 10),
                    _buildFinanceRow("Import Price (Cost)",
                        currencyFormatter.format(importPrice)),
                    _buildFinanceRow("Listing Price",
                        currencyFormatter.format(listingPrice)),
                    if (status == 'sold') ...[
                      const Divider(),
                      _buildFinanceRow("Final Sold Price",
                          currencyFormatter.format(finalSoldPrice),
                          isBold: true),
                      _buildFinanceRow("Sold At",
                          soldAtDisplay), // Use the safe display string
                      _buildFinanceRow(
                          "Net Profit", currencyFormatter.format(profit),
                          isBold: true,
                          color: profit >= 0
                              ? Colors.green.shade700
                              : Colors.red.shade700),
                    ]
                  ] else ...[
                    // --- Contact Button (Non-Admin) ---
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => _showFeedback("Contacting dealer...",
                            isError: false),
                        icon: const Icon(Icons.email, color: Colors.white),
                        label: const Text("Inquire About Vehicle",
                            style:
                                TextStyle(color: Colors.white, fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
