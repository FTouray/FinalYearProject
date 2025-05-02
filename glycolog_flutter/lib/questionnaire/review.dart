import 'package:glycolog/utils.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  ReviewScreenState createState() => ReviewScreenState();
}

class ReviewScreenState extends State<ReviewScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  Map<String, dynamic> _reviewData = {};
  final String? apiUrl = dotenv.env['API_URL'];     

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
        Uri.parse('$apiUrl/questionnaire/review/'),
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

  Future<void> _completeSession() async {
    final token = await AuthService().getAccessToken();
    if (token == null) return;

    final apiUrl = dotenv.env['API_URL'];
    final res = await http.post(
      Uri.parse('$apiUrl/questionnaire/complete/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (!mounted) return;

    if (res.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to complete session.')),
      );
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
                          title: FutureBuilder(
                            future:
                                formatGlucoseDynamic(glucose['glucose_level']),
                            builder: (context, snapshot) {
                              final formattedGlucose = snapshot.data ??
                                  glucose['glucose_level'].toString();
                              return Text(
                                  'Level: $formattedGlucose | Target Min: ${glucose['target_min']} | Target Max: ${glucose['target_max']}');
                            },
                          ),
                          subtitle: Text(
                              'Evaluation: ${glucose['evaluation']} | Timestamp: ${formatTimestamp(glucose['timestamp'])}'),

                        );
                      }),
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
                      }),
                      const Divider(),
                      const Text(
                        'Exercise Check:',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      ...(_reviewData['exercise_check'] as List)
                          .map((exercise) {
                        return ListTile(
                          title: Text(
                              'Intensity: ${exercise['exercise_intensity']} | Duration: ${exercise['exercise_duration']} mins'),
                          subtitle: Text(
                              'Feeling: ${exercise['post_exercise_feeling']}'),
                        );
                      }),
                      const Divider(),
                      const Text(
                        'Symptom Check:',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      ...(_reviewData['symptom_check'] as List).map((symptom) {
                        return ListTile(
                          title: Text('Symptoms: ${symptom['symptoms']}'),
                          subtitle: Text('Notes: ${symptom['notes']}'),
                        );
                      }),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () async {
                          await _completeSession(); 
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
                          'View Data Visualisation',
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
                          Navigator.pushReplacementNamed(
                              context, '/symptom-step');
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
