import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';

class SymptomStepScreen extends StatefulWidget {
  const SymptomStepScreen({Key? key}) : super(key: key);

  @override
  _SymptomStepScreenState createState() => _SymptomStepScreenState();
}

class _SymptomStepScreenState extends State<SymptomStepScreen> {
  final Map<String, bool> selectedSymptoms = {};
  final Map<String, dynamic> responseValues = {};

  final List<String> symptoms = [
    'Fatigue',
    'Headaches',
    'Dizziness',
    'Thirst',
    'Nausea',
    'Blurred Vision',
    'Irritability',
    'Sweating',
    'Frequent Urination',
    'Dry Mouth',
    'Slow Wound Healing',
    'Weight Loss',
    'Increased Hunger',
    'Shakiness',
    'Hunger',
    'Fast Heartbeat',
  ];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize dropdown-related keys with null
    responseValues["stress"] = null;
    responseValues["routine_change"] = null;
    responseValues["routine_change_details"] = null;
    responseValues["routine_effect"] = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Symptom Questionnaire'),
        backgroundColor: Colors.blue[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Progress Bar
            LinearProgressIndicator(
              value: 0.25, // Progress for step 1 of 4
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[800]!),
            ),
            const SizedBox(height: 20),

            // Symptoms Section
            _buildSectionTitle("Symptoms"),
            ..._buildSymptomQuestions(),
            _buildSectionTitle("Rest and Stress"),
            _buildSliderQuestion(
              question: "How many hours did you sleep last night?",
              min: 0,
              max: 10,
              divisions: 10,
              responseKey: "sleep_hours",
            ),
            _buildDropdownQuestion(
              question: "Are you feeling stressed today?",
              options: ["Yes", "No"],
              responseKey: "stress",
            ),

            // Routine Disruptions Section
            _buildSectionTitle("Routine Disruptions"),
            _buildDropdownQuestion(
              question:
                  "Have there been any recent changes to your daily routine?",
              options: ["Yes", "No"],
              responseKey: "routine_change",
            ),
            if (responseValues["routine_change"] == "Yes") ...[
              _buildDropdownQuestion(
                question: "What has changed?",
                options: [
                  "Work Schedule",
                  "Diet",
                  "Exercise",
                  "Sleep",
                  "Other"
                ],
                responseKey: "routine_change_details",
              ),
              _buildDropdownQuestion(
                question:
                    "Do you feel these changes have affected your mood or energy?",
                options: ["Yes", "No"],
                responseKey: "routine_effect",
              ),
            ],
            if (_isLoading) const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 20),
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
                  onPressed: _isLoading ? null : _submitData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build section titles
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Build symptom questions with severity sliders
  List<Widget> _buildSymptomQuestions() {
    return symptoms.map((symptom) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            title: Text(symptom),
            value: selectedSymptoms[symptom] ?? false,
            onChanged: (bool? value) {
              setState(() {
                selectedSymptoms[symptom] = value!;
                if (!value) responseValues.remove(symptom);
              });
            },
          ),
          if (selectedSymptoms[symptom] == true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Rate severity:"),
                  Slider(
                    value: (responseValues[symptom] as double?) ?? 3.0,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _getSeverityLabel(
                        (responseValues[symptom] as double?) ?? 3.0),
                    onChanged: (double value) {
                      setState(() {
                        responseValues[symptom] = value;
                      });
                    },
                  ),
                ],
              ),
            ),
        ],
      );
    }).toList();
  }

  // Build slider-based question
  Widget _buildSliderQuestion({
    required String question,
    required double min,
    required double max,
    required int divisions,
    required String responseKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(fontSize: 16),
        ),
        Slider(
          value: (responseValues[responseKey] as double?) ?? (min + max) / 2,
          min: min,
          max: max,
          divisions: divisions,
          label: "${responseValues[responseKey] ?? ((min + max) / 2)}",
          onChanged: (double value) {
            setState(() {
              responseValues[responseKey] = value;
            });
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Build dropdown-based question
  Widget _buildDropdownQuestion({
    required String question,
    required List<String> options,
    required String responseKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(fontSize: 16),
        ),
        DropdownButton<String>(
          value: responseValues[responseKey] as String?,
          isExpanded: true,
          hint: const Text("Select an option"),
          items: options.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: (String? value) {
            setState(() {
              responseValues[responseKey] = value;
            });
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Map severity values to labels
  String _getSeverityLabel(double value) {
    switch (value.toInt()) {
      case 1:
        return "Mild";
      case 2:
        return "Mild-Moderate";
      case 3:
        return "Moderate";
      case 4:
        return "Moderate-Severe";
      case 5:
        return "Severe";
      default:
        return "Unknown";
    }
  }

  Future<void> _submitData() async {
    if (!_validateInputs()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all required fields.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final data = {
      "symptoms": selectedSymptoms.entries
          .where((entry) => entry.value)
          .map((entry) => {
                "symptom": entry.key,
                "severity": responseValues[entry.key] ?? 3.0,
              })
          .toList(),
      "sleep_hours": responseValues["sleep_hours"],
      "stress": responseValues["stress"] == "Yes",
      "routine_change": responseValues["routine_change"],
      "responses": {
        "routine_effect": responseValues["routine_effect"],
        "routine_change_details": responseValues["routine_change_details"],
      },
    };

    String? token = await AuthService().getAccessToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User is not authenticated.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.12:8000/api/questionnaire/symptom-step/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        Navigator.pushNamed(context, '/glucose-step');
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${error['error']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _validateInputs() {
    if (responseValues["sleep_hours"] == null ||
        responseValues["stress"] == null ||
        responseValues["routine_change"] == null) {
      return false;
    }

    if (responseValues["routine_change"] == "Yes" &&
        responseValues["routine_change_details"] == null) {
      return false;
    }

    return true;
  }
}
