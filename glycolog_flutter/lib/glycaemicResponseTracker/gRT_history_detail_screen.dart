// ignore_for_file: avoid_print

import 'package:flutter/material.dart';

class MealDetailScreen extends StatelessWidget {
  final Map<String, dynamic> meal;

  MealDetailScreen({Key? key, required this.meal}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Print the entire meal object to the console
    print("Meal object: $meal");

    // Extract the food items from the meal object
    final foodItems = meal['food_item_ids'] ?? [];

    // Print the food items list to the console
    print("Food items: $foodItems");

    return Scaffold(
      appBar: AppBar(
        title: Text("Meal Details"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Meal ID: ${meal['mealId']}", style: TextStyle(fontSize: 20)),
            SizedBox(height: 10),
            Text("Timestamp: ${meal['timestamp']}", style: TextStyle(fontSize: 16)),
            SizedBox(height: 10),
            Text("Total GI: ${meal['total_glycaemic_index']}", style: TextStyle(fontSize: 16)),
            SizedBox(height: 10),
            Text("Total Carbs: ${meal['total_carbs']}", style: TextStyle(fontSize: 16)),
            SizedBox(height: 10),
            Text("Food Items:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...List.generate(foodItems.length, (index) {
              final foodItem = foodItems[index];
              return ListTile(
                title: Text(foodItem['name']),
                subtitle: Text("GI: ${foodItem['glycaemic_index']}, Carbs: ${foodItem['carbs']}g"),
              );
            }),
          ],
        ),
      ),
    );
  }
}
