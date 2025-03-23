import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  _AddMedicationScreenState createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  TextEditingController searchController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController dosageController = TextEditingController();
  TextEditingController frequencyController = TextEditingController();
  DateTime? lastTaken;
  List<Map<String, dynamic>> medicationList = [];
  List<Map<String, dynamic>> filteredList = [];
  bool isLoading = false;
  bool isManualEntry = false;
  final String? apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    fetchMedications(); // Fetch medications when screen loads
  }

  /// **Fetch all medications from RxNorm API**
  Future<void> fetchMedications() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('$apiUrl/fetch-medications/'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          medicationList = List<Map<String, dynamic>>.from(data['medications']);
          filteredList = List.from(medicationList); // Default list
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// **Filter medications dynamically based on search query**
  void filterMedications(String query) {
    setState(() {
      filteredList = medicationList
          .where(
              (med) => med['name'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  /// **Show a dialog to input dosage and frequency**
  void showMedicationInputDialog(String name, {String? rxnormId}) {
    dosageController.clear();
    frequencyController.clear();
    lastTaken = null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Enter Details for $name"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: dosageController,
                  decoration: const InputDecoration(labelText: "Dosage")),
              TextField(
                  controller: frequencyController,
                  decoration: const InputDecoration(labelText: "Frequency")),
              ListTile(
                title: const Text("Last Taken"),
                subtitle: Text(lastTaken != null
                    ? lastTaken!.toLocal().toString().split(' ')[0]
                    : "Not set"),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null) {
                      setState(() {
                        lastTaken = pickedDate;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            ElevatedButton(
                onPressed: () {
                  saveMedication(name, dosageController.text,
                      frequencyController.text, rxnormId);
                  Navigator.pop(context);
                },
                child: const Text("Save"))
          ],
        );
      },
    );
  }

  /// **Save selected or manually entered medication**
  Future<void> saveMedication(
      String name, String dosage, String frequency, String? rxnormId) async {
    String? token = await AuthService().getAccessToken();
    if (token == null) return;

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/save-medication/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: json.encode({
          'name': name,
          'rxnorm_id': rxnormId,
          'dosage': dosage,
          'frequency': frequency,
          'last_taken': lastTaken?.toIso8601String(),
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Medication saved successfully!")),
        );
      }
    } catch (e) {
      print("Error saving medication: $e");
    }
  }

  /// **OCR Scanner for Medication Label**
  Future<void> scanMedicationLabel() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile == null) return;
    String? token = await AuthService().getAccessToken();

    var request =
        http.MultipartRequest('POST', Uri.parse('$apiUrl/scan-medication/'));
    request.headers['Authorization'] = 'Bearer $token';
    request.files
        .add(await http.MultipartFile.fromPath('image', pickedFile.path));

    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    var jsonData = json.decode(responseData);

    if (response.statusCode == 200) {
      setState(() {
        nameController.text = jsonData['name']; // Autofill search
        isManualEntry = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning medication.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Medication")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: filterMedications,
                    decoration: const InputDecoration(
                        labelText: "Search or Enter Medication"),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: scanMedicationLabel, // OCR Scanner
                )
              ],
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final med = filteredList[index];
                        return Card(
                          child: ListTile(
                            title: Text(med['name']),
                            onTap: () {
                              showMedicationInputDialog(med['name'],
                                  rxnormId: med['rxnorm_id']);
                            },
                          ),
                        );
                      },
                    ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isManualEntry = true;
                });
              },
              child: const Text("Manually Enter Medication"),
            ),
            if (isManualEntry) ...[
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Medication Name"),
              ),
              TextField(
                controller: dosageController,
                decoration: const InputDecoration(labelText: "Dosage"),
              ),
              TextField(
                controller: frequencyController,
                decoration: const InputDecoration(labelText: "Frequency"),
              ),
              ElevatedButton(
                onPressed: () {
                  showMedicationInputDialog(nameController.text);
                },
                child: const Text("Save Medication"),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
