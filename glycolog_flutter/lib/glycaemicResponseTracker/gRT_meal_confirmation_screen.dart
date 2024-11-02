import 'dart:convert';

import 'package:Glycolog/glycaemicResponseTracker/gRT_main_screen.dart';
import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'gRT_meal_log_screen.dart';

class MealConfirmationScreen extends StatefulWidget {
  final List<FoodItem> selectedItems;
  final DateTime timestamp;

  const MealConfirmationScreen({
    Key? key,
    required this.selectedItems,
    required this.timestamp,
  }) : super(key: key);

  @override
  _MealConfirmationScreenState createState() => _MealConfirmationScreenState();
}

class _MealConfirmationScreenState extends State<MealConfirmationScreen> {
  double get totalGi =>
      widget.selectedItems.fold(0, (sum, item) => sum + item.gi);
  double get totalCarbs =>
      widget.selectedItems.fold(0, (sum, item) => sum + item.carbs);

  void _removeItem(FoodItem item) {
    setState(() {
      widget.selectedItems.remove(item);
    });
  }

  void _addMoreItems(BuildContext context) {
    Navigator.pop(context);
  }

   Future<void> _saveMeal() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('access_token');

      if (token == null) {
        print('No access token found');
        await AuthService().logout(context);
        return;
      }

      final response = await http.post(
        Uri.parse('http://192.168.1.19:8000/api/log-meal/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'timestamp': widget.timestamp.toIso8601String(),
          'food_item_ids': widget.selectedItems.map((item) => item.foodId).toList(),
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Meal saved successfully!')),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => GRTMainScreen()),
          (Route<dynamic> route) => false,
        );
      } else {
        print('Failed to save meal. Status code: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save meal.')),
        );
      }
    } catch (e) {
      print('Failed to save meal. Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save meal.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Confirm Your Meal',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: widget.selectedItems.length,
                itemBuilder: (context, index) {
                  final item = widget.selectedItems[index];
                  return Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[600],
                        child: const Icon(Icons.fastfood, color: Colors.white),
                      ),
                      title: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'GI: ${item.gi.toStringAsFixed(1)}, Carbs: ${item.carbs.toStringAsFixed(1)}g',
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: IconButton(
                        icon:
                            const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removeItem(item),
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    'Total GI: ${totalGi.toStringAsFixed(1)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total Carbs: ${totalCarbs.toStringAsFixed(1)}g',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _addMoreItems(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[400],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Add More',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                ElevatedButton(
                  onPressed: _saveMeal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Meal',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
