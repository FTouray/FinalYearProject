import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Glycolog/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'gL_confirmation_screen.dart';
import 'package:Glycolog/utils.dart';

class AddGlucoseLevelScreen extends StatefulWidget {
  const AddGlucoseLevelScreen({super.key});

  @override
  _AddGlucoseLevelScreenState createState() => _AddGlucoseLevelScreenState();
}

class _AddGlucoseLevelScreenState extends State<AddGlucoseLevelScreen> {
  final TextEditingController _glucoseLevelController = TextEditingController();
  DateTime _selectedDate = DateTime.now(); // Default to current date
  TimeOfDay _selectedTime = TimeOfDay.now();
  String measurementUnit = 'mg/dL'; // Default unit
  File? _pickedImage; // Store the picked image
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
      measurementUnit =
          prefs.getString('selectedUnit') ?? 'mg/dL'; // Default to mg/dL
    });
  }

  // Function to get a temporary file
  Future<File> getFile() async {
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/example.txt'; // Specify the file name
    return File(path);
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

  // Function to preprocess the image
  Future<File> _preprocessImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    if (image != null) {
      // Convert to grayscale
      img.Image grayscaleImage = img.grayscale(image);

      // Apply thresholding
      img.Image thresholdImage = img.copyResize(grayscaleImage,
          width: grayscaleImage.width, height: grayscaleImage.height);

      // Save the processed image to a temporary file
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/processed_image.png';
      final processedImageFile = File(path)
        ..writeAsBytesSync(img.encodePng(thresholdImage));

      return processedImageFile;
    } else {
      throw Exception('Failed to preprocess image');
    }
  }

  // Function to scan the glucose meter image
  Future<void> _scanGlucoseMeter(File imageFile) async {
    try {
      final processedImageFile = await _preprocessImage(imageFile);
      final inputImage = InputImage.fromFile(processedImageFile);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      double? glucoseValue; // Keep this nullable
      double maxHeight = 0; // Variable to keep track of the largest font size

      final regex =
          RegExp(r'\b\d+(\.\d+)?\b'); // Match both integers and decimals
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          for (TextElement element in line.elements) {
            // Match the element text with the regex to filter only valid numbers
            if (regex.hasMatch(element.text)) {
              double? value = double.tryParse(
                  element.text); // Try to parse the text as a double
              double textHeight = element
                  .boundingBox.height; // Get the height of the text element

              // Check for valid value and if it is the largest height found so far
              if (value != null && textHeight > maxHeight) {
                glucoseValue =
                    value; // Update to the value with the largest font size
                maxHeight = textHeight; // Update the largest font size
              }
            }
          }
        }
      }

      // Define valid ranges
      double minValue = (measurementUnit == 'mg/dL') ? 10 : 0.55;
      double maxValue = (measurementUnit == 'mg/dL') ? 600 : 33.3;

      // Validate the detected glucose value before setting it
      if (glucoseValue != null &&
          glucoseValue >= minValue &&
          glucoseValue <= maxValue) {
        setState(() {
          _glucoseLevelController.text =
              glucoseValue.toString(); // Auto-fill the scanned value
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Detected glucose level is out of valid range.')),
        );
      }

      // Dispose the recognizer when done
      textRecognizer.close();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process image: $e')),
      );
    }
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
        glucoseValue =
            convertToMgdL(glucoseValue); // Convert to mg/dL before saving
      }

      // Navigate to the confirmation screen
      Navigator.push(
        context,
        MaterialPageRoute(
          // Use MaterialPageRoute to pass data to the confirmation screen
          builder: (context) => GlucoseLogConfirmationScreen(
            glucoseLevel: double.parse(_glucoseLevelController.text),
            selectedDate: _selectedDate,
            selectedTime: _selectedTime,
            measurementUnit: measurementUnit,
            mealContext:
                _mealContext, // Pass meal context to confirmation screen
          ),
        ),
      ).then((confirmed) {
        if (confirmed == true) {
          _saveGlucoseLog(glucoseValue); // Save the glucose log if confirmed
        }
      });
    }
  }

  // Function to validate the input
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

      // Define ranges based on the selected measurement unit
      double minValue = (measurementUnit == 'mg/dL') ? 10 : 0.55;
      double maxValue = (measurementUnit == 'mg/dL') ? 600 : 33.3;

      // Check if the value is within the realistic range for the selected unit
      if (level < minValue || level > maxValue) {
        setState(() {
          errorMessage =
              'Please enter a glucose level between $minValue and $maxValue $measurementUnit.';
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
      // Uri.parse('http://10.0.2.2:8000/api/glucose-log/'), // For Emulator API endpoint
      Uri.parse('http://192.168.1.19:8000/api/glucose-log/'), // For Physical Device API endpoint
         // Uri.parse('http://172.20.10.3:8000/api/glucose-log/'), // Hotspot
      // Uri.parse('http://192.168.40.184:8000/api/glucose-log/'), // Ethernet IP
      
      headers: {
        'Authorization': 'Bearer $token', // Send the token in the header
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'glucose_level': glucoseLevel,
        'timestamp': formatDateTime(
            _selectedDate, _selectedTime), // Use the selected date and time
        'meal_context': _mealContext, // Include meal context
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
      // Navigate to the main glucose log page
      Navigator.pushReplacementNamed(context, '/glucose-log');
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
        title: const Text(
          'Add Glucose Level',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Glucose Level Entry
            _buildInputField(
              label: 'Glucose Level',
              controller: _glucoseLevelController,
              keyboardType: TextInputType.number,
              errorMessage: errorMessage,
              suffixText: measurementUnit,
            ),

            const SizedBox(height: 20),

            // OCR Scan Button
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan Glucose Meter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Display picked image if available
            if (_pickedImage != null)
              Image.file(
                _pickedImage!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            const SizedBox(height: 20),

            // Meal Context Dropdown
            _buildDropdownMenu(
              value: _mealContext,
              label: 'Meal Context',
              items: const [
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
              title: Text("Date: ${formatDate(_selectedDate)}"),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context),
            ),

            // Time Picker
            ListTile(
              title: Text("Time: ${formatTime(_selectedTime)}"),
              trailing: const Icon(Icons.access_time),
              onTap: () => _selectTime(context),
            ),

            const SizedBox(height: 20),

            // Submit Button
            ElevatedButton(
              onPressed: _submitData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800], // Confirm button color
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save Glucose Log',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required TextInputType keyboardType,
    String? suffixText,
    String? errorMessage,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: '$label ($measurementUnit)',
        suffixText: suffixText,
        errorText: errorMessage,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    );
  }

  // Dropdown menu
  Widget _buildDropdownMenu({
    required String value,
    required String label,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}