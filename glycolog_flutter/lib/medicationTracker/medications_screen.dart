import 'package:flutter/material.dart';
import 'package:Glycolog/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Import your utils.dart
import 'package:Glycolog/utils.dart'; // Adjust this path to match your project structure

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
        Uri.parse('$apiUrl/medications/list/'),
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
      setState(() {
        errorMessage = 'Error loading medications: $e';
        isLoading = false;
      });
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

  Future<void> deleteMedication(dynamic id, int index) async {
    final token = await AuthService().getAccessToken();
    if (token == null) return;

    try {
      final response = await http.delete(
        Uri.parse('$apiUrl/medications/delete/$id/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          medications.removeAt(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Medication deleted")),
        );
      } else {
        throw Exception("Failed to delete medication");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  /// Marks medication as taken "now" in ISO8601 format,
  /// then updates local list so the UI is in sync.
  Future<void> markAsTakenNow(
      Map<String, dynamic> medication, int index) async {
    final token = await AuthService().getAccessToken();
    if (token == null) return;

    final nowIsoString = DateTime.now().toIso8601String();

    try {
      final response = await http.put(
        Uri.parse('$apiUrl/medications/update/${medication['id']}/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'last_taken': nowIsoString,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          // Store the *full* ISO string locally
          medications[index]['last_taken'] = nowIsoString;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Medication marked as taken just now!")),
        );
      } else {
        throw Exception("Failed to update medication");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  /// Safely format the 'last_taken' field using formatTimestamp from utils.dart.
  /// If it's null or parsing fails, show "Not set".
  String formatLastTaken(Map<String, dynamic> med) {
    final raw = med['last_taken'];
    if (raw == null) return 'Not set';
    try {
      return formatTimestamp(raw); // from your utils.dart
    } catch (e) {
      return 'Not set';
    }
  }

  Widget _buildMedicationCard(Map<String, dynamic> med, int index) {
    return Dismissible(
      key: Key(med['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Delete Medication"),
            content: Text("Are you sure you want to delete '${med['name']}'?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Delete"),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => deleteMedication(med['id'], index),
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: ListTile(
          leading: const Icon(Icons.medication, color: Colors.blue),
          title: Text(
            med['name'],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Dosage: ${med['dosage']}"),
              Text("Frequency: ${med['frequency']}"),
              // Show "Last Taken" plus the icon side by side in a row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Last Taken: ${formatLastTaken(med)}",
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.access_time),
                    tooltip: 'Mark as just taken',
                    onPressed: () => markAsTakenNow(med, index),
                  ),
                ],
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => navigateToEditMedication(med),
              ),
              IconButton(
                icon: const Icon(Icons.alarm, color: Colors.green),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Medications')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : medications.isEmpty
              ? const Center(child: Text("No medications saved yet."))
              : ListView.builder(
                  itemCount: medications.length,
                  itemBuilder: (context, index) {
                    return _buildMedicationCard(medications[index], index);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/add-medication'),
        label: const Text("Add Medication"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
