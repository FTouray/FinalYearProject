import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ExerciseStepScreen extends StatefulWidget {
  const ExerciseStepScreen({Key? key}) : super(key: key);

  @override
  _ExerciseStepScreenState createState() => _ExerciseStepScreenState();
}

class _ExerciseStepScreenState extends State<ExerciseStepScreen> {
  String? lastExerciseTime;
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
    '2–3 Days Ago',
    'More than 5 Days Ago',
    'I Don’t Remember'
  ];

  final List<String> exerciseIntensities = [
    'Walking',
    'Running',
    'Yoga',
    'Strength Training',
    'Other'
  ];

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) {
        throw Exception('User is not authenticated.');
      }

      final data = {
        'last_exercise_time': lastExerciseTime,
        'exercise_intensity': exerciseIntensity,
        'exercise_duration': exerciseDuration,
        'post_exercise_feeling': postExerciseFeeling,
        'activity_level': activityLevel,
        'activity_barrier': activityLevel == 'Less' ? activityBarrier : null,
        'experienced_discomfort': experiencedDiscomfort,
        'discomfort_details': experiencedDiscomfort ? discomfortDetails : null,
      };

      final response = await http.post(
        Uri.parse('http://192.168.1.19:8000/api/questionnaire/exercise-step/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        // Navigate to a completion screen or summary
        Navigator.pushReplacementNamed(context, '/questionnaire-completed');
      } else {
        final error = jsonDecode(response.body);
        setState(() {
          errorMessage = error['error'] ?? 'An error occurred.';
        });
      }
    } catch (e) {
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Progress indicator at 100% for the last step
            LinearProgressIndicator(
              value: 1.0, // Full progress for the last step
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[800]!),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              decoration:
                  const InputDecoration(labelText: 'Last Exercise Time'),
              items: exerciseTimes
                  .map((time) =>
                      DropdownMenuItem(value: time, child: Text(time)))
                  .toList(),
              value: lastExerciseTime,
              onChanged: (value) {
                setState(() {
                  lastExerciseTime = value;
                });
              },
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              decoration:
                  const InputDecoration(labelText: 'Exercise Intensity'),
              items: exerciseIntensities
                  .map((intensity) => DropdownMenuItem(
                      value: intensity, child: Text(intensity)))
                  .toList(),
              value: exerciseIntensity,
              onChanged: (value) {
                setState(() {
                  exerciseIntensity = value;
                });
              },
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Exercise Duration (minutes)'),
                Slider(
                  value: exerciseDuration,
                  min: 0,
                  max: 60,
                  divisions: 12,
                  label: exerciseDuration.toStringAsFixed(0),
                  onChanged: (value) {
                    setState(() {
                      exerciseDuration = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              decoration:
                  const InputDecoration(labelText: 'Post-Exercise Feeling'),
              items: feelingsAfterExercise
                  .map((feeling) =>
                      DropdownMenuItem(value: feeling, child: Text(feeling)))
                  .toList(),
              value: postExerciseFeeling,
              onChanged: (value) {
                setState(() {
                  postExerciseFeeling = value;
                });
              },
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Activity Level'),
              items: activityLevels
                  .map((level) =>
                      DropdownMenuItem(value: level, child: Text(level)))
                  .toList(),
              value: activityLevel,
              onChanged: (value) {
                setState(() {
                  activityLevel = value;
                  if (value != 'Less') activityBarrier = null;
                });
              },
            ),
            const SizedBox(height: 20),
            if (activityLevel == 'Less')
              DropdownButtonFormField<String>(
                decoration:
                    const InputDecoration(labelText: 'Activity Barrier'),
                items: activityBarriers
                    .map((barrier) =>
                        DropdownMenuItem(value: barrier, child: Text(barrier)))
                    .toList(),
                value: activityBarrier,
                onChanged: (value) {
                  setState(() {
                    activityBarrier = value;
                  });
                },
              ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text('Experienced Discomfort?'),
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
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Back'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : _submitData,
                  child: const Text('Finish'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
