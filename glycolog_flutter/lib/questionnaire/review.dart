import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../services/auth_service.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({Key? key}) : super(key: key);

  @override
  _ReviewScreenState createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  Map<String, dynamic> _reviewData = {};

  @override
  void initState() {
    super.initState();
    _fetchReviewData();
  }

  Future<void> _fetchReviewData() async {
    try {
      String? token = await AuthService().getAccessToken();
      
      if (token == null) throw Exception('User not authenticated.');

      final response = await http.get(
        Uri.parse('http://192.168.1.11:8000/api/questionnaire/review/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _reviewData = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Your Answers'),
        backgroundColor: Colors.blue[800],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? const Center(child: Text('Error loading review data.'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      const Text(
                        'Glucose Check:',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      ...(_reviewData['glucose_check'] as List).map((glucose) {
                        return ListTile(
                          title: Text(
                              'Level: ${glucose['glucose_level']} | Target Min: ${glucose['target_min']} | Target Max: ${glucose['target_max']}'),
                          subtitle: Text(
                              'Evaluation: ${glucose['evaluation']} | Timestamp: ${glucose['timestamp']}'),
                        );
                      }).toList(),
                      const Divider(),
                      const Text(
                        'Meal Check:',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      ...(_reviewData['meal_check'] as List).map((meal) {
                        return ListTile(
                          title: Text(
                              'High GI Foods: ${meal['high_gi_foods'].map((item) => item['name']).join(", ")}'),
                          subtitle: Text(
                              'Skipped Meals: ${meal['skipped_meals'].join(", ")} | Wellness Impact: ${meal['wellness_impact']}'),
                        );
                      }).toList(),
                      const Divider(),
                      const Text(
                        'Exercise Check:',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      ...(_reviewData['exercise_check'] as List).map((exercise) {
                        return ListTile(
                          title: Text(
                              'Intensity: ${exercise['exercise_intensity']} | Duration: ${exercise['exercise_duration']} mins'),
                          subtitle: Text(
                              'Feeling: ${exercise['post_exercise_feeling']}'),
                        );
                      }).toList(),
                      const Divider(),
                      const Text(
                        'Symptom Check:',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      ...(_reviewData['symptom_check'] as List).map((symptom) {
                        return ListTile(
                          title: Text(
                              'Symptoms: ${symptom['symptoms']}'),
                          subtitle: Text('Notes: ${symptom['notes']}'),
                        );
                      }).toList(),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(
                              context, '/data-visualization');
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 15),
                          backgroundColor: Colors.blue[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: const Text(
                          'View Insights',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                        ),
                        child: const Text(
                          'Edit Answers',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
