import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'gRT_meal_confirmation_screen.dart';
import 'package:Glycolog/services/auth_service.dart';

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

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is FoodItem &&
            other.name == name &&
            other.gi == gi &&
            other.carbs == carbs);
  }

  @override
  int get hashCode => name.hashCode ^ gi.hashCode ^ carbs.hashCode;
}

class MealSelectionScreen extends StatefulWidget {
  const MealSelectionScreen({Key? key}) : super(key: key);

  @override
  _MealSelectionScreenState createState() => _MealSelectionScreenState();
}

class _MealSelectionScreenState extends State<MealSelectionScreen> {
  List<FoodCategory> _categories = [];
  List<FoodItem> selectedItems = [];
  int? _expandedCategoryId;
  Map<int, List<FoodItem>> _cachedFoodItems = {}; // Cache for food items

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
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
        setState(() {
          _categories = (json.decode(response.body) as List)
              .map((data) => FoodCategory(id: data['id'], name: data['name']))
              .toList();
        });
      } else {
        print('Failed to load categories. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to load categories. Error: $e');
    }
  }

  Future<void> _fetchFoodItems(int categoryId) async {
    if (_cachedFoodItems.containsKey(categoryId)) return;

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('access_token');

      if (token == null) {
        print('No access token found');
        await AuthService().logout(context);
        return;
      }

      final response = await http.get(
        Uri.parse(
            'http://192.168.1.19:8000/api/categories/$categoryId/food-items/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _cachedFoodItems[categoryId] = (json.decode(response.body) as List)
              .map((data) => FoodItem(
                    name: data['name'],
                    gi: data['glycaemic_index'],
                    carbs: data['carbs'],
                  ))
              .toList();
        });
      } else {
        print('Failed to load food items. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to load food items. Error: $e');
    }
  }

  void _toggleSelection(FoodItem item) {
    setState(() {
      if (selectedItems.contains(item)) {
        selectedItems.remove(item);
      } else {
        selectedItems.add(item);
      }
    });
  }

  void _goToConfirmation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealConfirmationScreen(
          selectedItems: selectedItems,
          timestamp: DateTime.now(),
        ),
      ),
    ).then((updatedItems) {
      if (updatedItems != null) {
        setState(() {
          selectedItems = updatedItems;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Meal Items'),
        backgroundColor: Colors.blue,
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
                          body: isExpanded
                              ? (_cachedFoodItems.containsKey(category.id)
                                  ? ListView(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      children: _cachedFoodItems[category.id]!
                                          .map((foodItem) {
                                        return ListTile(
                                          title: Text(foodItem.name),
                                          subtitle: Text(
                                              'GI: ${foodItem.gi}, Carbs: ${foodItem.carbs}g'),
                                          trailing: Checkbox(
                                            value: selectedItems
                                                .contains(foodItem),
                                            onChanged: (bool? value) {
                                              _toggleSelection(foodItem);
                                            },
                                          ),
                                        );
                                      }).toList(),
                                    )
                                  : FutureBuilder<void>(
                                      future: _fetchFoodItems(category.id),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const Center(
                                              child:
                                                  CircularProgressIndicator());
                                        } else {
                                          return const SizedBox();
                                        }
                                      },
                                    ))
                              : const SizedBox(),
                          isExpanded: isExpanded,
                        );
                      }).toList(),
                      expansionCallback: (int index, bool isExpanded) {
                        setState(() {
                          _expandedCategoryId =
                              isExpanded ?  _categories[index].id : null;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Selected Items: ${selectedItems.length}',
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
                          selectedItems.isEmpty ? null : _goToConfirmation,
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
