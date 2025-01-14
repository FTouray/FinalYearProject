import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../services/auth_service.dart';

class ExerciseStepScreen extends StatefulWidget {
  const ExerciseStepScreen({Key? key}) : super(key: key);

  @override
  _ExerciseStepScreenState createState() => _ExerciseStepScreenState();
}

class _ExerciseStepScreenState extends State<ExerciseStepScreen> {
  String? lastExerciseTime;
  String? exerciseType;
  String? exerciseIntensity;
  double exerciseDuration = 0;
  String? postExerciseFeeling;
  String? activityLevel;
  String? activityBarrier;
  bool experiencedDiscomfort = false;
  String? discomfortDetails;
  bool isLoading = false;
  String? errorMessage;

  final List<String> exerciseTimes = [
    'Today',
    '2-3 Days Ago',
    'More than 5 Days Ago',
    'I Don’t Remember'
  ];

  final List<String> exerciseTypes = [
    'Walking',
    'Running',
    'Yoga',
    'Strength Training',
    'Other'
  ];

  final List<String> exerciseIntensities = ['Low', 'Moderate', 'Vigorous'];

  final List<String> feelingsAfterExercise = ['Energised', 'Neutral', 'Tired'];

  final List<String> activityLevels = ['More', 'Less', 'About the Same'];

  final List<String> activityBarriers = [
    'Lack of time',
    'Fatigue',
    'Physical discomfort',
    'Other'
  ];

  Future<void> _submitData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      String? token = await AuthService().getAccessToken();
      if (token == null) throw Exception('User is not authenticated.');

      final data = {
        'last_exercise_time': lastExerciseTime,
        'exercise_type': exerciseType, // Update to use correct field
        'exercise_intensity': exerciseIntensity, // Add default if needed
        'exercise_duration': exerciseDuration,
        'post_exercise_feeling': postExerciseFeeling,
        'activity_level_comparison': activityLevel,
        'activity_barrier': activityLevel == 'Less' ? activityBarrier : null,
        'experienced_discomfort': experiencedDiscomfort,
        'discomfort_details': experiencedDiscomfort ? discomfortDetails : null,
      };

      print('Submitting data: $data'); // Debug: Log data being submitted

      final response = await http.post(
        Uri.parse('http://192.168.1.12:8000/api/questionnaire/exercise-step/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        print('Data submitted successfully: ${response.body}');
        Navigator.pushReplacementNamed(context, '/review');
      } else {
        final error = jsonDecode(response.body);
        print(
            'Server responded with error: $error'); // Debug: Log server error response
        setState(() {
          errorMessage = error['error'] ?? 'An error occurred.';
        });
      }
    } catch (e) {
      print('Error submitting data: $e'); // Debug: Log any exceptions
      setState(() {
        errorMessage = 'An error occurred: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Details'),
        backgroundColor: Colors.blue[800],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: 1.0,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[800]!),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tell us about your recent exercise:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildDropdownField(
                label: 'Last Exercise Time',
                value: lastExerciseTime,
                items: exerciseTimes,
                onChanged: (value) {
                  setState(() {
                    lastExerciseTime = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              _buildDropdownField(
                label: 'Exercise Type',
                value: exerciseType,
                items: exerciseTypes,
                onChanged: (value) {
                  setState(() {
                    exerciseType = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              _buildDropdownField(
                label: 'Exercise Intensity',
                value: exerciseIntensity,
                items: exerciseIntensities,
                onChanged: (value) {
                  setState(() {
                    exerciseIntensity = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              _buildSliderField(
                label: 'Exercise Duration (minutes)',
                value: exerciseDuration,
                min: 0,
                max: 60,
                divisions: 12,
                onChanged: (value) {
                  setState(() {
                    exerciseDuration = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              _buildDropdownField(
                label: 'Post-Exercise Feeling',
                value: postExerciseFeeling,
                items: feelingsAfterExercise,
                onChanged: (value) {
                  setState(() {
                    postExerciseFeeling = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              _buildDropdownField(
                label: 'Activity Level Compared to Usual',
                value: activityLevel,
                items: activityLevels,
                onChanged: (value) {
                  setState(() {
                    activityLevel = value;
                    if (value != 'Less') activityBarrier = null;
                  });
                },
              ),
              const SizedBox(height: 20),
              if (activityLevel == 'Less')
                _buildDropdownField(
                  label: 'Reason for Less Activity',
                  value: activityBarrier,
                  items: activityBarriers,
                  onChanged: (value) {
                    setState(() {
                      activityBarrier = value;
                    });
                  },
                ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text(
                  'Experienced Discomfort?',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                value: experiencedDiscomfort,
                onChanged: (value) {
                  setState(() {
                    experiencedDiscomfort = value;
                    if (!value) discomfortDetails = null;
                  });
                },
              ),
              if (experiencedDiscomfort)
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Discomfort Details',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      discomfortDetails = value;
                    });
                  },
                ),
              const SizedBox(height: 20),
              if (isLoading) const Center(child: CircularProgressIndicator()),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Back',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: isLoading ? null : _submitData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 24),
                    ),
                    child: const Text(
                      'Finish',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
      value: value,
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required void Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: '${value.toStringAsFixed(0)} mins',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
