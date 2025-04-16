import 'dart:convert';
import 'package:glycolog/glycaemicResponseTracker/gRT_main_screen.dart';
import 'package:glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'grt_meal_log_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MealConfirmationScreen extends StatefulWidget {
  final List<FoodItem> selectedItems;
  final DateTime timestamp;

  const MealConfirmationScreen({
    super.key,
    required this.selectedItems,
    required this.timestamp,
  });

  @override
  _MealConfirmationScreenState createState() => _MealConfirmationScreenState();
}

class _MealConfirmationScreenState extends State<MealConfirmationScreen> {
  double get totalGi =>
      widget.selectedItems.fold(0, (sum, item) => sum + item.gi);
  double get totalCarbs =>
      widget.selectedItems.fold(0, (sum, item) => sum + item.carbs);

  final TextEditingController mealNameController = TextEditingController();
  final String? apiUrl = dotenv.env['API_URL'];

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
      
      if (!mounted) return;

      if (token == null) {
        print('No access token found');
        await AuthService().logout(context);
        return;
      }

      final response = await http.post(
        Uri.parse('$apiUrl/log-meal/'), 
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': mealNameController.text.trim().isEmpty ? '' : mealNameController.text.trim(),
          'timestamp': widget.timestamp.toIso8601String(),
          'food_item_ids': widget.selectedItems.map((item) => item.foodId).toList(),
        }),
      );

    if (!mounted) return;

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
        print('❌ Body: ${response.body}');
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
            TextField(
              controller: mealNameController,
              decoration: InputDecoration(
                labelText: 'Meal Name (Optional)',
                hintText: 'Enter a name for your meal...',
                prefixIcon: Icon(Icons.restaurant, color: Colors.blue[700]),
                filled: true,
                fillColor: Colors.blue[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.blue.shade200, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.blue.shade800, width: 2.0),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                hintStyle: TextStyle(color: Colors.blueGrey[300]),
              ),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
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
