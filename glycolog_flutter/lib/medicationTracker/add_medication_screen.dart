import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  _AddMedicationScreenState createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController dosageController = TextEditingController();
  final TextEditingController frequencyController = TextEditingController();

  DateTime? lastTaken;
  List<Map<String, dynamic>> medicationList = [];
  List<Map<String, dynamic>> filteredList = [];
  bool isLoading = false;
  bool isManualEntry = false;
  final String? apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    loadDefaultMedications();
    // You can show suggestions or start blank until user types
  }

Future<void> fetchMedications(String query) async {
    setState(() => isLoading = true);

    if (query.trim().isEmpty) {
      setState(() {
        filteredList = List.from(medicationList);
        isLoading = false;
      });
      return;
    }

    try {
      final token = await AuthService().getAccessToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('$apiUrl/medications/search/?query=$query'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> meds = data['medications'];

        setState(() {
          filteredList = List<Map<String, dynamic>>.from(meds);
        });
      } else {
        print("Failed to fetch medications: ${response.body}");
      }
    } catch (e) {
      print("Error fetching medications: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }


void showMedicationInputDialog(String name,
      {String? rxnormId, List<String>? dosageForms, String? defaultFrequency}) {
    // Auto-fill dosage if available
    if (dosageForms != null && dosageForms.isNotEmpty) {
      dosageController.text = dosageForms.first;
    }

    // Auto-fill frequency
    frequencyController.text = defaultFrequency ??
        (frequencyController.text.isNotEmpty
            ? frequencyController.text
            : "Once daily");


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
                decoration: InputDecoration(
                  labelText: "Dosage",
                  suffixIcon: PopupMenuButton<String>(
                    icon: Icon(Icons.arrow_drop_down),
                    onSelected: (value) => dosageController.text = value,
                    itemBuilder: (_) => [
                      PopupMenuItem(value: "500mg", child: Text("500mg")),
                      PopupMenuItem(value: "10mg", child: Text("10mg")),
                    ],
                  ),
                ),
              ),
              TextField(
                controller: frequencyController,
                decoration: const InputDecoration(labelText: "Frequency"),
              ),
              ListTile(
                title: const Text("Last Taken"),
                subtitle: Text(
                  lastTaken != null
                      ? lastTaken!.toLocal().toString().split(' ')[0]
                      : "Not set",
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => lastTaken = picked);
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                saveMedication(name, dosageController.text,
                    frequencyController.text, rxnormId);
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }


  Future<void> saveMedication(
      String name, String dosage, String frequency, String? rxnormId) async {
    final token = await AuthService().getAccessToken();
    if (token == null) return;

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/medications/save/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
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

Future<void> scanMedicationLabel() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile == null) return;

    final token = await AuthService().getAccessToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$apiUrl/medications/scan/'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.files
        .add(await http.MultipartFile.fromPath('image', pickedFile.path));

    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    final jsonData = json.decode(responseData);

    if (response.statusCode == 200) {
      final scannedName = jsonData['name'] ?? '';
      final scannedDosage = jsonData['dosage'] ?? '';
      final scannedFrequency = jsonData['frequency'] ?? '';

      setState(() {
        searchController.text = scannedName;
        nameController.text = scannedName;
        dosageController.text = scannedDosage;
        frequencyController.text = scannedFrequency;
        isManualEntry = true;
      });

      fetchMedications(scannedName);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error scanning medication.")),
      );
    }
  }

  void loadDefaultMedications() {
  // Top 50 or so common medications (you can replace these later)
  medicationList = [
    {"name": "Paracetamol", "rxnorm_id": null},
    {"name": "Ibuprofen", "rxnorm_id": null},
    {"name": "Amoxicillin", "rxnorm_id": null},
    {"name": "Aspirin", "rxnorm_id": null},
    {"name": "Omeprazole", "rxnorm_id": null},
    {"name": "Metformin", "rxnorm_id": null},
    {"name": "Simvastatin", "rxnorm_id": null},
    {"name": "Atorvastatin", "rxnorm_id": null},
    {"name": "Cetirizine", "rxnorm_id": null},
    {"name": "Loratadine", "rxnorm_id": null},
    {"name": "Prednisone", "rxnorm_id": null},
    {"name": "Azithromycin", "rxnorm_id": null},
    {"name": "Salbutamol", "rxnorm_id": null},
    {"name": "Levothyroxine", "rxnorm_id": null},
    {"name": "Naproxen", "rxnorm_id": null},
    {"name": "Furosemide", "rxnorm_id": null},
    {"name": "Hydrochlorothiazide", "rxnorm_id": null},
    {"name": "Losartan", "rxnorm_id": null},
    {"name": "Gabapentin", "rxnorm_id": null},
    {"name": "Tramadol", "rxnorm_id": null},
    {"name": "Codeine", "rxnorm_id": null},
    {"name": "Doxycycline", "rxnorm_id": null},
    {"name": "Ciprofloxacin", "rxnorm_id": null},
    {"name": "Fluoxetine", "rxnorm_id": null},
    {"name": "Sertraline", "rxnorm_id": null},
    {"name": "Diazepam", "rxnorm_id": null},
    {"name": "Alprazolam", "rxnorm_id": null},
    {"name": "Zolpidem", "rxnorm_id": null},
    {"name": "Insulin", "rxnorm_id": null},
    {"name": "Ranitidine", "rxnorm_id": null},
    {"name": "Pantoprazole", "rxnorm_id": null},
    {"name": "Clindamycin", "rxnorm_id": null},
    {"name": "Lisinopril", "rxnorm_id": null},
    {"name": "Citalopram", "rxnorm_id": null},
    {"name": "Bupropion", "rxnorm_id": null},
    {"name": "Trazodone", "rxnorm_id": null},
    {"name": "Venlafaxine", "rxnorm_id": null},
    {"name": "Buspirone", "rxnorm_id": null},
    {"name": "Propranolol", "rxnorm_id": null},
    {"name": "Clonazepam", "rxnorm_id": null},
    {"name": "Esomeprazole", "rxnorm_id": null},
    {"name": "Warfarin", "rxnorm_id": null},
    {"name": "Clopidogrel", "rxnorm_id": null},
    {"name": "Montelukast", "rxnorm_id": null},
    {"name": "Meloxicam", "rxnorm_id": null},
    {"name": "Tamsulosin", "rxnorm_id": null},
    {"name": "Finasteride", "rxnorm_id": null},
    {"name": "Nitrofurantoin", "rxnorm_id": null},
    {"name": "Methotrexate", "rxnorm_id": null},
  ];

  setState(() {
    filteredList = List.from(medicationList);
  });
}

Future<Map<String, dynamic>> fetchMedicationDetails(String rxnormId) async {
    final token = await AuthService().getAccessToken();
    if (token == null) return {};

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/medications/details/?rxcui=$rxnormId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      }
    } catch (e) {
      print("Error fetching med details: $e");
    }

    return {};
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
                    onChanged: (value) {
                      if (value.trim().isNotEmpty) {
                        fetchMedications(value);
                      } else {
                        setState(() => filteredList = []);
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: "Search or Enter Medication",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: scanMedicationLabel,
                ),
              ],
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredList.isEmpty
                      ? const Center(child: Text("No results."))
                      : ListView.builder(
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final med = filteredList[index];
                            return Card(
                              child: ListTile(
                                title: Text(med['name']),
                                onTap: () async {
                                  final details = await fetchMedicationDetails(
                                      med['rxcui']);

                                  showMedicationInputDialog(
                                    med['name'],
                                    rxnormId: med['rxcui'],
                                    dosageForms:
                                        details['dosage_forms']?.cast<String>(),
                                    defaultFrequency:
                                        details['default_frequency'],
                                  );
                                },

                              ),
                            );
                          },
                        ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text("Can't find it? Add it manually:"),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text("Manual Entry"),
              onPressed: () => setState(() => isManualEntry = true),
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
            ],
          ],
        ),
      ),
    );
  }
}
