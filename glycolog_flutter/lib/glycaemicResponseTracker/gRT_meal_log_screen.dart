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
  final int foodId;
  final String name;
  final double gi;
  final double carbs;

  FoodItem({required this.foodId,required this.name, required this.gi, required this.carbs});

  @override
bool operator ==(Object other) =>
      identical(this, other) || (other is FoodItem && other.foodId == foodId);

  @override
  int get hashCode => foodId.hashCode;
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
  List<FoodItem> _allFoodItems = [];
  List<FoodItem> _filteredFoodItems = [];
  TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _searchController.addListener(_filterFoodItems);
  }

  Future<void> _fetchCategories() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        print('No access token found');
        await AuthService().logout(context);
        return;
      }

      final response = await http.get(
        Uri.parse('http://192.168.1.11:8000/api/categories'), // Physical Device
        // Uri.parse('http://172.20.10.3:8000/api/categories/'), // Hotspot
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
        Uri.parse('http://192.168.1.11:8000/api/categories/$categoryId/food-items/'), // Physical Device
       // Uri.parse('http://172.20.10.3:8000/api/categories/$categoryId/food-items/'), // Hotspot
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _cachedFoodItems[categoryId] = (json.decode(response.body) as List)
              .map((data) => FoodItem(
                    foodId: data['foodId'],     
                    name: data['name'],
                    gi: data['glycaemic_index'],
                    carbs: data['carbs'], 
                  ))
              .toList();
          _allFoodItems.addAll(_cachedFoodItems[categoryId]!);
        });
      } else {
        print('Failed to load food items. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to load food items. Error: $e');
    }
  }

void _filterFoodItems() {
  setState(() {
    _isSearching = _searchController.text.isNotEmpty;
    if (_isSearching) {
        // Global search across all items
        _filteredFoodItems = _allFoodItems.where((item) => item.name.toLowerCase().contains(_searchController.text.toLowerCase())).toList();
    } else {
      _filteredFoodItems = [];
    }
  });
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

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _isSearching = false;
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
    return GestureDetector(
      onTap: () {
        // Clear search results on tapping outside
        FocusScope.of(context).unfocus();
        _clearSearch();
      },
      child: Scaffold(
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
            : Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => _filterFoodItems(),
                      decoration: InputDecoration(
                        hintText: 'Search Food Items...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15.0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Dynamic Content based on Search
                  Expanded(
                    child: _searchController.text.isNotEmpty &&
                            _filteredFoodItems.isNotEmpty
                        ? _buildSearchResults()
                        : _buildCategoryList(),
                  ),

                  // Selected Items and Review Button
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Text(
                          'Selected Items: ${selectedItems.length}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.blue,
                          ),
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
                ],
              ),
      ),
    );
  }


// Widget to display search results
Widget _buildSearchResults() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: _filteredFoodItems.length,
      itemBuilder: (context, index) {
        final foodItem = _filteredFoodItems[index];
        return ListTile(
          title: Text(foodItem.name),
          subtitle: Text('GI: ${foodItem.gi}, Carbs: ${foodItem.carbs}g'),
          trailing: Checkbox(
            value: selectedItems.contains(foodItem),
            onChanged: (bool? value) {
              _toggleSelection(foodItem);
            },
          ),
        );
      },
    );
  }

// Widget to display categories with expandable food items
Widget _buildCategoryList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final isExpanded = _expandedCategoryId == category.id;
        return Card(
          elevation: 4, // Adds shadow to the card
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            title: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  // Static fast food icon for all categories
                  Icon(Icons.fastfood, color: Colors.blue),
                  SizedBox(width: 8),
                  // Dynamically scale the category name
                  Expanded(
                    child: FittedBox(
                      // Automatically adjusts text size
                      fit: BoxFit.scaleDown, // Ensures it does not overflow
                      child: Text(
                        category.name,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            initiallyExpanded: isExpanded,
            onExpansionChanged: (isExpanded) {
              setState(() {
                _expandedCategoryId = isExpanded ? category.id : null;
                if (isExpanded && !_cachedFoodItems.containsKey(category.id)) {
                  _fetchFoodItems(category.id);
                }
              });
            },
            children: (_cachedFoodItems[category.id] ?? []).map((foodItem) {
              return ListTile(
                title: Text(foodItem.name),
                subtitle: Text('GI: ${foodItem.gi}, Carbs: ${foodItem.carbs}g'),
                trailing: Checkbox(
                  value: selectedItems.contains(foodItem),
                  onChanged: (bool? value) {
                    _toggleSelection(foodItem);
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

 @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

}