import 'package:flutter/material.dart';

class MealDetailScreen extends StatelessWidget {
  final Map<String, dynamic> meal;

  MealDetailScreen({Key? key, required this.meal}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Print the entire meal object to the console for debugging
    print("Meal object: $meal");

    // Extract the food items from the meal object
    final foodItems = meal['food_items'] ?? [];
    print("Food items: $foodItems");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Meal Details"),
        backgroundColor: Colors.blue[800], // Match the color scheme
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meal ID Card
            _buildInfoCard(
              icon: Icons.fastfood,
              title: 'Meal ID',
              content: '${meal['mealId']}',
              context: context,
            ),
            const SizedBox(height: 20),

            // Timestamp Card
            _buildInfoCard(
              icon: Icons.calendar_today,
              title: 'Timestamp',
              content: '${meal['timestamp']}',
              context: context,
            ),
            const SizedBox(height: 20),

            // Total GI Card
            _buildInfoCard(
              icon: Icons.show_chart,
              title: 'Total GI',
              content: '${meal['total_glycaemic_index']}',
              context: context,
            ),
            const SizedBox(height: 20),

            // Total Carbs Card
            _buildInfoCard(
              icon: Icons.receipt_long,
              title: 'Total Carbs',
              content: '${meal['total_carbs']}g',
              context: context,
            ),
            const SizedBox(height: 20),

            // Food Items Section
            const Text(
              "Food Items:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: foodItems.length,
                itemBuilder: (context, index) {
                  final foodItem = foodItems[index];
                  return _buildFoodItemCard(foodItem);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to create consistent info cards for each meal detail
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required BuildContext context,
  }) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.blue[800]),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: const TextStyle(fontSize: 18, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // New method to build a card for each food item
  Widget _buildFoodItemCard(Map<String, dynamic> foodItem) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Placeholder for food item image
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Container(
                color: Colors.grey[300], // Grey background as a placeholder
                width: 60,
                height: 60,
                child: Center(
                  child: Icon(
                    Icons
                        .fastfood, // You could replace this with an actual image
                    size: 30,
                    color: Colors.blue[800],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    foodItem['name'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "GI: ${foodItem['glycaemic_index']}, Carbs: ${foodItem['carbs']}g",
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
