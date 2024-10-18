import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Import the OCR package
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Glycolog/services/auth_service.dart'; // Import your auth service
import 'package:http/http.dart' as http; // Import HTTP package for API requests
import 'dart:convert'; // Import Dart's convert library for JSON encoding/decoding
import 'gL_confirmation_screen.dart'; // Import the confirmation screen

class AddGlucoseLevelScreen extends StatefulWidget {
  const AddGlucoseLevelScreen({super.key});

  @override
  _AddGlucoseLevelScreenState createState() => _AddGlucoseLevelScreenState();
}

class _AddGlucoseLevelScreenState extends State<AddGlucoseLevelScreen> {
  final TextEditingController _glucoseLevelController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String measurementUnit = 'mg/dL'; // Default unit
  File? _pickedImage;
  String? errorMessage;
  String _mealContext = 'fasting'; // Default meal context

  @override
  void initState() {
    super.initState();
    _loadUserSettings(); // Load user settings to get the measurement unit
  }

  Future<void> _loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      measurementUnit = prefs.getString('selectedUnit') ?? 'mg/dL'; // Default to mg/dL
    });
  }

  // Function to pick an image from the camera
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
      });
      await _scanGlucoseMeter(_pickedImage!); // Call OCR scan function
    }
  }

  // Function to scan the glucose meter using OCR
  Future<void> _scanGlucoseMeter(File imageFile) async {
    final InputImage inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(); // Initialize the TextRecognizer
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

    // Scan for numbers within the recognized text (for glucose level)
    String? glucoseValue; // Keep this nullable to check if it gets assigned

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        for (TextElement element in line.elements) {
          if (RegExp(r'^\d+$').hasMatch(element.text)) {
            glucoseValue = element.text; // Assume it's the glucose value
            break;
          }
        }
        if (glucoseValue != null) break; // Exit outer loop if glucoseValue is found
      }
      if (glucoseValue != null) break; // Exit outer loop if glucoseValue is found
    }

    // Set the scanned value in the text field
    if (glucoseValue != null) {
      setState(() {
        _glucoseLevelController.text = glucoseValue!; // Auto-fill the scanned value
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No valid glucose level detected.')),
      );
    }

    // Dispose the recognizer when done
    textRecognizer.close();
  }

  // Function to pick the date
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  // Function to pick the time
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (pickedTime != null && pickedTime != _selectedTime) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  // Function to validate input and submit data
  void _submitData() {
    if (_validateInput()) {
      double glucoseValue = double.parse(_glucoseLevelController.text);

      // Convert glucose level to a single unit for storage
      if (measurementUnit == 'mmol/L') {
        glucoseValue = convertToMgdL(glucoseValue); // Convert to mg/dL before saving
      }

      // Navigate to the confirmation screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GlucoseLogConfirmationScreen(
            glucoseLevel: double.parse(_glucoseLevelController.text),
            selectedDate: _selectedDate,
            selectedTime: _selectedTime,
            measurementUnit: measurementUnit,
            mealContext: _mealContext, // Pass meal context to confirmation screen
          ),
        ),
      ).then((confirmed) {
        if (confirmed == true) {
          _saveGlucoseLog(glucoseValue);
        }
      });
    }
  }

  bool _validateInput() {
    String glucoseLevel = _glucoseLevelController.text;

    if (glucoseLevel.isEmpty) {
      setState(() {
        errorMessage = 'Please enter or scan your glucose level.';
      });
      return false;
    }

    try {
      double level = double.parse(glucoseLevel);

      // Set realistic range based on measurement unit
      double minValue = (measurementUnit == 'mg/dL') ? 10 : 1; // Lower threshold based on unit
      double maxValue = (measurementUnit == 'mg/dL') ? 600 : 33; // Upper threshold for mmol/L

      // Check if the value is within the realistic range
      if (level < minValue || level > maxValue) {
        setState(() {
          errorMessage = 'Please enter a glucose level between $minValue and $maxValue $measurementUnit.';
        });
        return false;
      }

      // Validate date is not in the future
      if (_selectedDate.isAfter(DateTime.now())) {
        setState(() {
          errorMessage = 'Please select a date that is not in the future.';
        });
        return false;
      }

      // If validation passes
      setState(() {
        errorMessage = null;
      });
      return true;
    } catch (e) {
      // If the input is not a valid number
      setState(() {
        errorMessage = 'Please enter a valid numeric glucose level.';
      });
      return false;
    }
  }

  Future<void> _saveGlucoseLog(double glucoseLevel) async {
    String? token = await AuthService().getAccessToken();
    final response = await http.post(
      Uri.parse('http://10.0.2.2:8000/api/glucose-log/'), // Update with your API endpoint
      headers: {
        'Authorization': 'Bearer $token', // Send the token in the header
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'glucoseLevel': glucoseLevel,
        'timestamp': DateTime.now().toIso8601String(), // Use the current date and time
        'mealContext': _mealContext,  // Include meal context
      }),
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Glucose log added successfully!')),
      );
      _glucoseLevelController.clear(); // Clear the input field
      setState(() {
        _pickedImage = null; // Clear the picked image after saving
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add glucose log. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Glucose Level'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Glucose Level Entry
            TextField(
              controller: _glucoseLevelController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Glucose Level ($measurementUnit)', // Show unit in the label
                errorText: errorMessage,
              ),
            ),
            const SizedBox(height: 20),

            // OCR Scan Button
            ElevatedButton.icon(
              onPressed: _pickImage, // Pick image to scan
              icon: Icon(Icons.camera_alt),
              label: Text('Scan Glucose Meter'),
            ),
            const SizedBox(height: 20),

            // Display picked image (if any)
            if (_pickedImage != null)
              Image.file(
                _pickedImage!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            const SizedBox(height: 20),

            // Meal Context Dropdown
            DropdownButtonFormField<String>(
              value: _mealContext,
              decoration: InputDecoration(
                labelText: 'Meal Context',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'fasting', child: Text('Fasting')),
                DropdownMenuItem(value: 'pre_meal', child: Text('Pre-Meal')),
                DropdownMenuItem(value: 'post_meal', child: Text('Post-Meal')),
              ],
              onChanged: (String? newValue) {
                setState(() {
                  _mealContext = newValue!;
                });
              },
            ),
            const SizedBox(height: 20),

            // Date Picker
            ListTile(
              title: Text("Date: ${_selectedDate.toLocal()}".split(' ')[0]),
              trailing: Icon(Icons.calendar_today),
              onTap: () => _selectDate(context),
            ),

            // Time Picker
            ListTile(
              title: Text("Time: ${_selectedTime.format(context)}"),
              trailing: Icon(Icons.access_time),
              onTap: () => _selectTime(context),
            ),

            const SizedBox(height: 20),

            // Submit Button
            ElevatedButton(
              onPressed: _submitData,
              child: Text('Save Glucose Log'),
            ),
          ],
        ),
      ),
    );
  }
}

// Conversion function to convert mmol/L to mg/dL
double convertToMgdL(double value) {
  return value * 18.01559; // Convert mmol/L to mg/dL
}
