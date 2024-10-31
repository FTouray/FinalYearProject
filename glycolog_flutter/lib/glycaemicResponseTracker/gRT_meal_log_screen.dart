import 'package:Glycolog/glycaemicResponseTracker/gRT_meal_confirmation_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class FoodCategory {
  final int id;
  final String name;

  FoodCategory({required this.id, required this.name});
}

class FoodItem {
  final String name;
  final double gi;
  final double carbs;

  FoodItem({required this.name, required this.gi, required this.carbs});
}

class MealSelectionScreen extends StatefulWidget {
  const MealSelectionScreen({Key? key}) : super(key: key);

  @override
  _MealSelectionScreenState createState() => _MealSelectionScreenState();
}

class _MealSelectionScreenState extends State<MealSelectionScreen> {
  List<FoodCategory> _categories = [];
  List<FoodItem> _foodItems = [];
  List<FoodItem> _selectedItems = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token =
          prefs.getString('access_token'); // Retrieve the stored access token

      if (token == null) {
        print('No access token found');
        return;
      }

      print('Access token: $token');

      final response = await http.get(
        Uri.parse('http://192.168.1.19:8000/api/categories'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        setState(() {
          _categories = (json.decode(response.body) as List)
              .map((data) => FoodCategory(
                    id: data['id'],
                    name: data['name'],
                  ))
              .toList();
        });
        print('Categories loaded: $_categories');
      } else {
        // Handle error
        print('Failed to load categories. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Failed to load categories. Error: $e');
    }
  }

  Future<void> _fetchFoodItems(int categoryId) async {
    final response = await http
        .get(Uri.parse('http://192.168.1.19:8000/api/food_items?category_id=$categoryId'));
    if (response.statusCode == 200) {
      setState(() {
        _foodItems = (json.decode(response.body) as List)
            .map((data) => FoodItem(
                  name: data['name'],
                  gi: data['gi'],
                  carbs: data['carbs'],
                ))
            .toList();
      });
    } else {
      // Handle error
      print('Failed to load food items');
    }
  }

  void _toggleSelection(FoodItem item) {
    setState(() {
      if (_selectedItems.contains(item)) {
        _selectedItems.remove(item);
      } else {
        _selectedItems.add(item);
      }
    });
  }

  void _goToConfirmation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealConfirmationScreen(
          selectedItems: _selectedItems,
          timestamp: DateTime.now(),
        ),
      ),
    );
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Meal Items'),
        backgroundColor: Colors.blue[800],
      ),
      body: _categories.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  flex: 2,
                  child: ListView.builder(
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return ListTile(
                        title: Text(category.name),
                        onTap: () => _fetchFoodItems(category.id),
                      );
                    },
                  ),
                ),
                Divider(),
                Expanded(
                  flex: 3,
                  child: _foodItems.isEmpty
                      ? Center(
                          child: Text(
                            'Select a category to view food items',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _foodItems.length,
                          itemBuilder: (context, index) {
                            final foodItem = _foodItems[index];
                            return ListTile(
                              title: Text(foodItem.name),
                              subtitle: Text(
                                  'GI: ${foodItem.gi}, Carbs: ${foodItem.carbs}'),
                              trailing: Checkbox(
                                value: _selectedItems.contains(foodItem),
                                onChanged: (bool? value) {
                                  _toggleSelection(foodItem);
                                },
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 20),
                Text('Selected Items: ${_selectedItems.length}',
                    style: const TextStyle(fontSize: 16)),
                ElevatedButton(
                  onPressed: _selectedItems.isEmpty ? null : _goToConfirmation,
                  child: const Text('Review Meal'),
                ),
              ],
            ),
    );
  }
}
