import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  FoodItem({
    required this.foodId,
    required this.name,
    required this.gi,
    required this.carbs,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is FoodItem && other.foodId == foodId);

  @override
  int get hashCode => foodId.hashCode;
}

class MealStepScreen extends StatefulWidget {
  const MealStepScreen({super.key});

  @override
  MealStepScreenState createState() => MealStepScreenState();
}

class MealStepScreenState extends State<MealStepScreen> {
  List<FoodCategory> _categories = [];
  List<FoodItem> selectedItems = [];
  List<String> skippedMeals = ['Breakfast', 'Lunch', 'Dinner'];
  List<String> selectedSkippedMeals = [];
  bool wellnessImpact = false;
  bool _isLoading = false;
  String? _error;
  final TextEditingController _notesController = TextEditingController();
  int? _expandedCategoryId;
  final Map<int, List<FoodItem>> _cachedFoodItems = {};
  final List<FoodItem> _allFoodItems = [];
  List<FoodItem> _filteredFoodItems = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  final String? apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _searchController.addListener(_filterFoodItems);
  }

  Future<void> _fetchCategories() async {
    try {
      String? token = await AuthService().getAccessToken();
      if (token == null) throw Exception('No access token found.');

      final response = await http.get(
        Uri.parse('$apiUrl/categories'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final fetched = (json.decode(response.body) as List)
            .map((data) => FoodCategory(id: data['id'], name: data['name']))
            .toList();

        setState(() => _categories = fetched);

        for (var category in fetched) {
          await _fetchFoodItems(category.id);
        }
      }
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }

  Future<void> _fetchFoodItems(int categoryId) async {
    if (_cachedFoodItems.containsKey(categoryId)) return;

    try {
      String? token = await AuthService().getAccessToken();
      if (token == null) throw Exception('No access token found.');

      final response = await http.get(
        Uri.parse('$apiUrl/categories/$categoryId/food-items/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _cachedFoodItems[categoryId] = (json.decode(response.body) as List)
              .map((data) => FoodItem(
                    foodId: data['foodId'],
                    name: data['name'],
                    gi: (data['glycaemic_index'] ?? 0.0).toDouble(),
                    carbs: (data['carbs'] ?? 0.0).toDouble(),
                  ))
              .toList();
          _allFoodItems.addAll(_cachedFoodItems[categoryId]!);
        });
      }
    } catch (e) {
      print('Error fetching food items: $e');
    }
  }

  void _filterFoodItems() {
    setState(() {
      _isSearching = _searchController.text.isNotEmpty;
      _filteredFoodItems = _isSearching
          ? _allFoodItems
              .where((item) => item.name
                  .toLowerCase()
                  .contains(_searchController.text.toLowerCase()))
              .toList()
          : [];
    });
  }

  void _toggleSelection(FoodItem item) {
    setState(() {
      selectedItems.contains(item)
          ? selectedItems.remove(item)
          : selectedItems.add(item);
    });
  }

  void _toggleSkippedMeal(String meal) {
    setState(() {
      selectedSkippedMeals.contains(meal)
          ? selectedSkippedMeals.remove(meal)
          : selectedSkippedMeals.add(meal);
    });
  }

  Future<void> _submitMealCheck() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String? token = await AuthService().getAccessToken();
      if (token == null) throw Exception('User is not authenticated.');

      final data = {
        'high_gi_food_ids': selectedItems.map((item) => item.foodId).toList(),
        'skipped_meals': selectedSkippedMeals,
        'wellness_impact': wellnessImpact,
        'notes': _notesController.text,
      };

      final response = await http.post(
        Uri.parse('$apiUrl/questionnaire/meal-step/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        if (!mounted) return;
        Navigator.pushNamed(context, '/exercise-step');
      } else {
        final error = jsonDecode(response.body);
        setState(() {
          _error = error['error'] ?? 'An error occurred.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'An error occurred: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Check'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: 0.75,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 20),
              const Text('Did you skip any meals today?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ...skippedMeals.map((meal) => CheckboxListTile(
                    title: Text(meal),
                    value: selectedSkippedMeals.contains(meal),
                    onChanged: (_) => _toggleSkippedMeal(meal),
                  )),
              const SizedBox(height: 20),
              const Text('Select foods you’ve eaten recently:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search Food Items...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _isSearching ? _buildSearchResults() : _buildCategoryList(),
              const SizedBox(height: 20),
              const Text('Did your diet affect your wellness today?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SwitchListTile(
                title: const Text('Wellness Impact'),
                subtitle: const Text(
                    'Toggle if your diet had an impact on how you felt'),
                value: wellnessImpact,
                onChanged: (bool value) {
                  setState(() {
                    wellnessImpact = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              const Text('Additional Notes:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter any notes here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back', style: TextStyle(fontSize: 16)),
                  ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitMealCheck,
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    child: const Text('Next', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              if (_isLoading) const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredFoodItems.length,
      itemBuilder: (context, index) {
        final foodItem = _filteredFoodItems[index];
        return ListTile(
          title: Text(foodItem.name),
          subtitle: Text('GI: ${foodItem.gi}, Carbs: ${foodItem.carbs}g'),
          trailing: Checkbox(
            value: selectedItems.contains(foodItem),
            onChanged: (_) => _toggleSelection(foodItem),
          ),
        );
      },
    );
  }

  Widget _buildCategoryList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final isExpanded = _expandedCategoryId == category.id;
        return Card(
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ExpansionTile(
            title: Text(category.name),
            initiallyExpanded: isExpanded,
            onExpansionChanged: (expanded) {
              setState(() {
                _expandedCategoryId = expanded ? category.id : null;
                if (expanded && !_cachedFoodItems.containsKey(category.id)) {
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
                  onChanged: (_) => _toggleSelection(foodItem),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
