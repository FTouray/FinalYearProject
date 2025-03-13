import 'package:flutter/material.dart';
import 'package:Glycolog/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  _MedicationsScreenState createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  List<Map<String, dynamic>> medications = [];
  bool isLoading = true;
  String? errorMessage;
  final String? apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    fetchSavedMedications();
  }

  Future<void> fetchSavedMedications() async {
    setState(() => isLoading = true);
    String? token = await AuthService().getAccessToken();
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/get-saved-medications/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          medications = List<Map<String, dynamic>>.from(data['medications']);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => errorMessage = 'Error loading medications: $e');
    }
  }

  void navigateToEditMedication(Map<String, dynamic> medication) {
    Navigator.pushNamed(
      context,
      '/edit-medication',
      arguments: medication,
    ).then((result) {
      if (result == true) fetchSavedMedications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Medications')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: medications.length,
                    itemBuilder: (context, index) {
                      final med = medications[index];
                      return Card(
                        child: ListTile(
                          title: Text(med['name']),
                          subtitle: Text(
                              "Dosage: ${med['dosage']} | Frequency: ${med['frequency']} | Last Taken: ${med['last_taken'] ?? 'Not set'}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => navigateToEditMedication(med),
                              ),
                              IconButton(
                                icon: const Icon(Icons.alarm,
                                    color: Colors.green),
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/medication-reminder',
                                    arguments: med,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/add-medication'),
                  child: const Text("Add Medication"),
                ),
              ],
            ),
    );
  }
}
