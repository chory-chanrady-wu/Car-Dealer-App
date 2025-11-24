import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'car_detail_screen.dart'; // Import detail screen

class CarScreen extends StatefulWidget {
  const CarScreen({super.key});

  @override
  State<CarScreen> createState() => _CarScreenState();
}

class _CarScreenState extends State<CarScreen> {
  // IMPORTANT: Using 10.0.2.2 for Android emulator compatibility
  final String apiUrl = "http://localhost:3000/cars";

  List<dynamic> cars = [];
  List<dynamic> filteredCars = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchCars();
    searchController.addListener(() => _runFilter(searchController.text));
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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

  Future<void> fetchCars() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        setState(() {
          // Assuming 'brand' is used in the backend response, map it to 'brand'
          cars = json
              .decode(response.body)
              .map((car) => {...car, 'brand': car['brand'] ?? car['brand']})
              .toList();
          filteredCars = cars;
          isLoading = false;
        });
      } else {
        _showFeedback("Failed to fetch cars: ${response.statusCode}",
            isError: true);
        setState(() => isLoading = false);
      }
    } catch (e) {
      _showFeedback("Network error fetching cars: $e", isError: true);
      setState(() => isLoading = false);
    }
  }

  void _runFilter(String query) {
    List<dynamic> results = query.isEmpty
        ? cars
        : cars
            .where((car) =>
                (car['brand']?.toLowerCase() ?? '')
                    .contains(query.toLowerCase()) ||
                (car['model']?.toLowerCase() ?? '')
                    .contains(query.toLowerCase()))
            .toList();
    setState(() => filteredCars = results);
  }

  // --- IMAGE PICKER (MULTI) - WITH SIZE CONSTRAINTS FOR STABILITY ---
  Future<List<String>> _pickImages(BuildContext dialogContext) async {
    final ImagePicker picker = ImagePicker();
    List<String> base64Images = [];

    try {
      // ADDING MAX WIDTH/HEIGHT TO REDUCE IMAGE SIZE AND IMPROVE STABILITY
      final List<XFile> images = await picker.pickMultiImage(
        imageQuality: 70, // Slightly higher quality, still compressed
        maxWidth: 800,
        maxHeight: 800,
      );

      if (images.isEmpty) return [];

      // Notify the user about processing time
      _showFeedback('Processing ${images.length} images...', isError: false);

      for (var img in images) {
        try {
          final Uint8List bytes = await img.readAsBytes();
          base64Images.add(base64Encode(bytes));
        } catch (e) {
          print("Error converting file ${img.path} to Base64: $e");
          // Continue processing other images
        }
      }

      _showFeedback('${base64Images.length} images ready for upload.',
          isError: false);
      return base64Images;
    } catch (e) {
      print("Image Picker Error caught: $e");
      _showFeedback('Failed to pick images. Check device permissions.',
          isError: true);
      return [];
    }
  }

  Future<void> addCar(String brand, String model, String year,
      String importPrice, String price, List<String> images) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "brand": brand,
          "model": model,
          "year": int.tryParse(year) ?? 0,
          "import_price": double.tryParse(importPrice) ?? 0.0,
          "price": double.tryParse(price) ?? 0.0,
          "images": images
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showFeedback("Car added successfully!");
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['details'] ?? 'Unknown error';
        _showFeedback(
            "Failed to add car (Code ${response.statusCode}): $errorMessage",
            isError: true);
      }
    } catch (e) {
      _showFeedback("Network/Server Error during addCar: $e", isError: true);
    }

    await fetchCars();
    if (!mounted) return;
    Navigator.pop(context); // Close dialog
  }

  Future<void> markAsSold(int id) async {
    final soldPriceCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Mark as Sold"),
        content: TextField(
          controller: soldPriceCtrl,
          decoration: const InputDecoration(labelText: "Final Sale Price"),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (soldPriceCtrl.text.isNotEmpty) {
                try {
                  final response = await http.put(
                    Uri.parse("$apiUrl/$id/sell"),
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode(
                        {"sold_price": double.tryParse(soldPriceCtrl.text)}),
                  );
                  if (response.statusCode == 200) {
                    _showFeedback("Car marked as sold successfully!");
                  } else {
                    _showFeedback(
                        "Failed to mark as sold: ${response.statusCode}",
                        isError: true);
                  }
                } catch (e) {
                  _showFeedback("Network Error during sale: $e", isError: true);
                }

                await fetchCars();
                if (!context.mounted) return;
                Navigator.pop(context);
              }
            },
            child: const Text("Confirm Sale"),
          )
        ],
      ),
    );
  }

  Future<void> deleteCar(int id) async {
    try {
      final response = await http.delete(Uri.parse("$apiUrl/$id"));
      if (response.statusCode == 200 || response.statusCode == 204) {
        _showFeedback("Car deleted successfully!");
      } else {
        _showFeedback("Failed to delete car: ${response.statusCode}",
            isError: true);
      }
    } catch (e) {
      _showFeedback("Network Error during delete: $e", isError: true);
    }

    fetchCars();
  }

  void _showAddCarDialog() {
    final brandCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final yearCtrl = TextEditingController();
    final importCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    // Declare state variables inside the builder scope for local state management
    List<String> selectedImages = [];
    bool isPickingImagesDialog = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Add New Vehicle"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Image Preview ---
                  if (selectedImages.isNotEmpty)
                    Container(
                      height: 80,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedImages.length,
                        itemBuilder: (ctx, i) => Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.memory(
                              base64Decode(selectedImages[i]),
                              width: 80,
                              fit: BoxFit.cover,
                              // Error builder to handle potential bad base64 data
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                width: 80,
                                height: 80,
                                color: Colors.red[100],
                                child: const Icon(Icons.broken_image,
                                    color: Colors.red),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // --- Image Picker Button ---
                  OutlinedButton.icon(
                    icon: isPickingImagesDialog
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_library),
                    label: Text(isPickingImagesDialog
                        ? "Processing Images..."
                        : "Select Images (${selectedImages.length})"),
                    onPressed: isPickingImagesDialog
                        ? null
                        : () async {
                            // 1. Start loading state
                            setDialogState(() => isPickingImagesDialog = true);

                            // 2. Pick images and wait for conversion
                            List<String> imgs = await _pickImages(context);

                            // 3. Stop loading and update image list
                            setDialogState(() {
                              selectedImages = imgs;
                              isPickingImagesDialog = false;
                            });
                          },
                  ),

                  const SizedBox(height: 10),

                  // --- Input Fields ---
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
                      decoration: const InputDecoration(
                          labelText: "Import Price (Cost)"),
                      keyboardType: TextInputType.number),
                  TextField(
                      controller: priceCtrl,
                      decoration:
                          const InputDecoration(labelText: "Listing Price"),
                      keyboardType: TextInputType.number),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")),
              ElevatedButton(
                // Disable Add button while images are processing or required fields are empty
                onPressed: isPickingImagesDialog ||
                        brandCtrl.text.isEmpty ||
                        priceCtrl.text.isEmpty ||
                        importCtrl.text.isEmpty
                    ? null
                    : () {
                        addCar(brandCtrl.text, modelCtrl.text, yearCtrl.text,
                            importCtrl.text, priceCtrl.text, selectedImages);
                      },
                child: const Text("Add"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get role from route arguments
    final String userRole =
        (ModalRoute.of(context)?.settings.arguments as String?) ?? 'user';
    final bool isAdmin = userRole == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Inventory'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              onChanged: _runFilter,
              decoration: InputDecoration(
                hintText: "Search by brand or Model...",
                fillColor: Colors.white,
                filled: true,
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 10.0, horizontal: 15.0),
              ),
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredCars.isEmpty && searchController.text.isEmpty
              ? const Center(child: Text("No cars in inventory. Add one!"))
              : filteredCars.isEmpty && searchController.text.isNotEmpty
                  ? Center(
                      child:
                          Text("No results for \"${searchController.text}\""))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: filteredCars.length,
                      itemBuilder: (context, index) {
                        final car = filteredCars[index];
                        final isSold = car['status'] == 'sold';
                        // Use the first image from the list as the thumbnail
                        final thumbnail =
                            car['images'] != null && car['images'].isNotEmpty
                                ? car['images'][0] as String?
                                : null;

                        // Image widget logic (Handles Base64 decode errors and provides a fallback)
                        Widget imageWidget = thumbnail != null
                            ? Image.memory(
                                base64Decode(thumbnail),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey[400],
                                  child: const Icon(
                                      Icons.photo_size_select_actual,
                                      color: Colors.white),
                                ),
                              )
                            : Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[200],
                                child: const Icon(Icons.directions_car,
                                    color: Colors.grey));

                        Widget cardContent = Card(
                          elevation: 3,
                          color: isSold ? Colors.grey[50] : Colors.white,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(10),
                            leading: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: imageWidget),
                            title: Text(
                                "${car['brand'] ?? ''} ${car['model'] ?? ''} (${car['year'] ?? ''})",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSold
                                        ? Colors.grey[600]
                                        : Colors.black,
                                    decoration: isSold
                                        ? TextDecoration.lineThrough
                                        : null)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("\$${car['price']} ",
                                    style: TextStyle(
                                        color: isSold
                                            ? Colors.red
                                            : Colors.green.shade700,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                                Text("ID: ${car['id']}",
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600]))
                              ],
                            ),

                            // CLICK TO VIEW DETAILS
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CarDetailScreen(
                                      carId: car['id'], isAdmin: isAdmin),
                                ),
                              );
                            },
                            trailing: isAdmin
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isSold)
                                        IconButton(
                                            icon: const Icon(
                                                Icons.monetization_on,
                                                color: Colors.green),
                                            onPressed: () =>
                                                markAsSold(car['id'])),
                                      IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () =>
                                              deleteCar(car['id'])),
                                    ],
                                  )
                                : (isSold
                                    ? const Text("SOLD",
                                        style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold))
                                    : null),
                          ),
                        );

                        // Admin users can swipe to delete
                        return isAdmin
                            ? Dismissible(
                                key: ValueKey(car['id']
                                    .toString()), // Using ValueKey for better stability
                                direction: DismissDirection.endToStart,
                                background: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(Icons.delete,
                                        color: Colors.white)),
                                onDismissed: (_) => deleteCar(car['id']),
                                confirmDismiss: (direction) async {
                                  // Implement a confirmation dialog here if desired
                                  return true;
                                },
                                child: cardContent)
                            : cardContent;
                      },
                    ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: _showAddCarDialog, child: const Icon(Icons.add))
          : null,
    );
  }
}
