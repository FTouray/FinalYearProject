import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  _AddMedicationScreenState createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  TextEditingController nameController = TextEditingController();
  TextEditingController dosageController = TextEditingController();
  TextEditingController frequencyController = TextEditingController();
  DateTime? lastTaken;
  List<Map<String, dynamic>> medicationList = [];
  bool isLoading = false;
  final String? apiUrl = dotenv.env['API_URL'];

  /// **Fetch medications from RxNorm API**
  Future<void> fetchMedications(String query) async {
    if (query.isEmpty) return;

    setState(() => isLoading = true);
    try {
      final response =
          await http.get(Uri.parse('$apiUrl/fetch-medications/?query=$query'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          medicationList = List<Map<String, dynamic>>.from(data['medications']);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  /// **Save Medication**
  Future<void> saveMedication() async {
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
          'name': nameController.text,
          'dosage': dosageController.text,
          'frequency': frequencyController.text,
          'last_taken': lastTaken?.toIso8601String(),
        }),
      );

      if (response.statusCode == 201) {
        Navigator.pop(context, true); // Return to Medications Screen
      }
    } catch (e) {
      print("Error saving medication: $e");
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
            TextField(
              controller: nameController,
              onChanged: fetchMedications,
              decoration: const InputDecoration(
                  labelText: "Search or Enter Medication"),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: medicationList.length,
                      itemBuilder: (context, index) {
                        final med = medicationList[index];
                        return ListTile(
                          title: Text(med['name']),
                          onTap: () {
                            setState(() {
                              nameController.text = med['name'];
                            });
                          },
                        );
                      },
                    ),
            ),
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
            ElevatedButton(
                onPressed: saveMedication,
                child: const Text("Save Medication")),
          ],
        ),
      ),
    );
  }
}
