import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final String apiUrl = "http://localhost:3000/reports/stats";

  bool isLoading = true;
  int totalSold = 0;
  double totalRevenue = 0.0;
  double totalProfit = 0.0;
  List<dynamic> recentSales = [];

  @override
  void initState() {
    super.initState();
    fetchStats();
  }

  Future<void> fetchStats() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          totalSold = data['total_sold'];
          totalRevenue =
              double.tryParse(data['total_revenue'].toString()) ?? 0.0;
          totalProfit = double.tryParse(data['total_profit'].toString()) ??
              0.0; // New Field
          recentSales = data['recent_sales'];
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching reports: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sales Report")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCards(),
                  const SizedBox(height: 25),
                  const Text(
                    "Recent Transactions",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildRecentSalesList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        // Total Revenue Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Colors.indigo, Colors.blueAccent]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.indigo.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Total Revenue",
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 5),
              Text(
                "\$${totalRevenue.toStringAsFixed(2)}",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text("$totalSold Cars Sold",
                        style: const TextStyle(color: Colors.white)),
                  ),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 15),

        // Net Profit Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Net Profit",
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 5),
                  Text(
                    "\$${totalProfit.toStringAsFixed(2)}",
                    style: const TextStyle(
                        color: Colors.green,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.trending_up, color: Colors.white),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSalesList() {
    if (recentSales.isEmpty) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(20),
              child: Text("No sales recorded yet.")));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentSales.length,
      itemBuilder: (context, index) {
        final car = recentSales[index];
        final profit = double.tryParse(car['profit'].toString()) ?? 0.0;
        final isPositive = profit >= 0;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isPositive
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              child: Icon(
                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isPositive ? Colors.green : Colors.red),
            ),
            title: Text(
              "${car['brand']} ${car['model']} ${car['year']} \$${car['import_price']}",
              style: const TextStyle(
                  fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "Sold: ${car['sold_at']?.toString().split('T')[0] ?? 'N/A'} for \$${car['sold_price']}",
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "Profit",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  "${isPositive ? '+' : ''}\$${profit.toStringAsFixed(2)}",
                  style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
