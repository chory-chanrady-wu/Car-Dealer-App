import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CarScreen extends StatefulWidget {
  const CarScreen({super.key});

  @override
  State<CarScreen> createState() => _CarScreenState();
}

class _CarScreenState extends State<CarScreen> {
  final String apiUrl = "http://localhost:3000/cars";

  List<dynamic> cars = [];
  List<dynamic> filteredCars = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();

  // Role will be set in build
  String userRole = 'user';

  @override
  void initState() {
    super.initState();
    fetchCars();
  }

  Future<void> fetchCars() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        setState(() {
          cars = json.decode(response.body);
          filteredCars = cars;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _runFilter(String query) {
    List<dynamic> results = query.isEmpty
        ? cars
        : cars
              .where(
                (car) =>
                    car['make'].toLowerCase().contains(query.toLowerCase()) ||
                    car['model'].toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
    setState(() => filteredCars = results);
  }

  // ... (Keep API Add/Edit/Delete/Sell methods same as before) ...
  Future<void> addCar(
    String make,
    String model,
    String year,
    String price,
  ) async {
    await http.post(
      Uri.parse(apiUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "make": make,
        "model": model,
        "year": int.parse(year),
        "price": double.parse(price),
      }),
    );
    await fetchCars();
    _runFilter(searchController.text);
    Navigator.pop(context);
  }

  Future<void> editCar(
    int id,
    String make,
    String model,
    String year,
    String price,
  ) async {
    await http.put(
      Uri.parse("$apiUrl/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "make": make,
        "model": model,
        "year": int.parse(year),
        "price": double.parse(price),
      }),
    );
    await fetchCars();
    _runFilter(searchController.text);
    Navigator.pop(context);
  }

  Future<void> markAsSold(int id) async {
    await http.put(Uri.parse("$apiUrl/$id/sell"));
    fetchCars();
  }

  Future<void> deleteCar(int id) async {
    await http.delete(Uri.parse("$apiUrl/$id"));
    fetchCars();
  }

  void _showCarDialog({Map? car}) {
    final isEdit = car != null;
    final makeCtrl = TextEditingController(text: isEdit ? car['make'] : '');
    final modelCtrl = TextEditingController(text: isEdit ? car['model'] : '');
    final yearCtrl = TextEditingController(
      text: isEdit ? car['year'].toString() : '',
    );
    final priceCtrl = TextEditingController(
      text: isEdit ? car['price'].toString() : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? "Edit Vehicle" : "Add Vehicle"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: makeCtrl,
                decoration: const InputDecoration(labelText: "Make"),
              ),
              TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(labelText: "Model"),
              ),
              TextField(
                controller: yearCtrl,
                decoration: const InputDecoration(labelText: "Year"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: "Price"),
                keyboardType: TextInputType.number,
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
              if (makeCtrl.text.isNotEmpty) {
                if (isEdit)
                  editCar(
                    car['id'],
                    makeCtrl.text,
                    modelCtrl.text,
                    yearCtrl.text,
                    priceCtrl.text,
                  );
                else
                  addCar(
                    makeCtrl.text,
                    modelCtrl.text,
                    yearCtrl.text,
                    priceCtrl.text,
                  );
              }
            },
            child: Text(isEdit ? "Save" : "Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get Role
    userRole = ModalRoute.of(context)!.settings.arguments as String? ?? 'user';
    final bool isAdmin = userRole == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              onChanged: _runFilter,
              decoration: InputDecoration(
                hintText: "Search...",
                fillColor: Colors.white,
                filled: true,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: filteredCars.length,
              itemBuilder: (context, index) {
                final car = filteredCars[index];
                final isSold = car['status'] == 'sold';

                // CARD CONTENT
                Widget cardContent = Card(
                  elevation: 3,
                  color: isSold ? Colors.grey[200] : Colors.white,
                  child: ListTile(
                    // Only allow tap to edit if Admin
                    onTap: isAdmin ? () => _showCarDialog(car: car) : null,
                    leading: CircleAvatar(
                      backgroundColor: isSold ? Colors.grey : Colors.indigo,
                      child: const Icon(
                        Icons.directions_car,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      "${car['year']} ${car['make']} ${car['model']}",
                      style: TextStyle(
                        decoration: isSold ? TextDecoration.lineThrough : null,
                        color: isSold ? Colors.grey : Colors.black,
                      ),
                    ),
                    subtitle: Text("\$${car['price']}"),

                    // Only show Sell Button if Admin
                    trailing: isAdmin
                        ? (isSold
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.grey,
                                )
                              : IconButton(
                                  icon: const Icon(
                                    Icons.sell,
                                    color: Colors.indigo,
                                  ),
                                  onPressed: () => markAsSold(car['id']),
                                ))
                        : (isSold
                              ? const Text(
                                  "SOLD",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null),
                  ),
                );

                // Wrap in Dismissible only if Admin
                if (isAdmin) {
                  return Dismissible(
                    key: Key(car['id'].toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => deleteCar(car['id']),
                    child: cardContent,
                  );
                } else {
                  return cardContent;
                }
              },
            ),
      // Only show Add Button if Admin
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showCarDialog(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
