// ignore_for_file: avoid_print

import 'package:Glycolog/glycaemicResponseTracker/gRT_meal_confirmation_screen.dart';
import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Model class for FoodCategory
class FoodCategory {
  final int id;
  final String name;

  FoodCategory({required this.id, required this.name});
}

// Model class for FoodItem
class FoodItem {
  final String name;
  final double gi;
  final double carbs;

  FoodItem({required this.name, required this.gi, required this.carbs});
}

// StatefulWidget for Meal Selection Screen
class MealSelectionScreen extends StatefulWidget {
  const MealSelectionScreen({Key? key}) : super(key: key);

  @override
  _MealSelectionScreenState createState() => _MealSelectionScreenState();
}

class _MealSelectionScreenState extends State<MealSelectionScreen> {
  // Lists to hold categories and selected items
  List<FoodCategory> _categories = [];
  List<FoodItem> _selectedItems = [];
  int? _expandedCategoryId;

  @override
  void initState() {
    super.initState();
    // Fetch categories when the screen initializes
    _fetchCategories();
  }

  // Method to fetch categories from the server
  Future<void> _fetchCategories() async {
    try {
      // Retrieve the stored access token
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('access_token');

      if (token == null) {
        print('No access token found');
        await AuthService().logout(context);
        return;
      }

      final response = await http.get(
        Uri.parse('http://192.168.1.19:8000/api/categories'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Parse the response and update the categories list
        setState(() {
          _categories = (json.decode(response.body) as List)
              .map((data) => FoodCategory(id: data['id'], name: data['name']))
              .toList();
        });
        print('Categories loaded: $_categories');
      } else {
        print('Failed to load categories. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to load categories. Error: $e');
    }
  }

  // Method to fetch food items for a selected category
Future<List<FoodItem>> _fetchFoodItems(int categoryId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('access_token');

      if (token == null) {
        print('No access token found');
        await AuthService().logout(context);
        return [];
      }

      final response = await http.get(
        Uri.parse(
            'http://192.168.1.19:8000/api/categories/$categoryId/food-items/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return (json.decode(response.body) as List)
            .map((data) => FoodItem(
                  name: data['name'],
                  gi: data['glycaemic_index'],
                  carbs: data['carbs'],
                ))
            .toList();
      } else {
        print('Failed to load food items. Status code: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Failed to load food items. Error: $e');
      return [];
    }
  }

  // Method to toggle selection of a food item
  void _toggleSelection(FoodItem item) {
    setState(() {
      if (_selectedItems.contains(item)) {
        _selectedItems.remove(item);
      } else {
        _selectedItems.add(item);
      }
    });
  }

  // Method to navigate to the confirmation screen
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
        backgroundColor: Colors.blue,
        elevation: 4,
      ),
      body: _categories.isEmpty
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ExpansionPanelList(
                      expandedHeaderPadding:
                          const EdgeInsets.symmetric(vertical: 8.0),
                      elevation: 1,
                      children: _categories.map<ExpansionPanel>((category) {
                        final isExpanded = _expandedCategoryId == category.id;
                        return ExpansionPanel(
                          headerBuilder:
                              (BuildContext context, bool isExpanded) {
                            return Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.fastfood, color: Colors.blue[700]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      category.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          body: isExpanded // Display food items when expanded
                              ? FutureBuilder<List<FoodItem>>(
                                  future: _fetchFoodItems(category.id),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    } else if (snapshot.hasError) {
                                      return Center(
                                          child:
                                              Text('Error: ${snapshot.error}'));
                                    } else if (!snapshot.hasData ||
                                        snapshot.data!.isEmpty) {
                                      return const Center(
                                          child: Text('No food items found.'));
                                    }

                                    // Display food items when fetched
                                    return ListView(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      children: snapshot.data!.map((foodItem) {
                                        return ListTile(
                                          title: Text(foodItem.name),
                                          subtitle: Text(
                                              'GI: ${foodItem.gi}, Carbs: ${foodItem.carbs}g'),
                                          trailing: Checkbox(
                                            value: _selectedItems
                                                .contains(foodItem),
                                            onChanged: (bool? value) {
                                              _toggleSelection(foodItem);
                                            },
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                )
                              : SizedBox(), // Return an empty container when not expanded
                          isExpanded: isExpanded,
                        );
                      }).toList(),
                      expansionCallback: (int index, bool isExpanded) {
                       print('Index: $index, IsExpanded: $isExpanded');
                       print(
                            'Before setState - Index: $index, IsExpanded: $isExpanded, Current Expanded ID: $_expandedCategoryId');
                        setState(() {
                          _expandedCategoryId = isExpanded ?  _categories[index].id : null;
                          print('Expanded Category ID: $_expandedCategoryId');
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Selected Items: ${_selectedItems.length}', // Count of selected items
                      style: const TextStyle(fontSize: 16, color: Colors.blue),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 15),
                      ),
                      onPressed:
                          _selectedItems.isEmpty ? null : _goToConfirmation,
                      child: const Text(
                        'Review Meal',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
