import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:glycolog/services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  AddMedicationScreenState createState() => AddMedicationScreenState();
}

class AddMedicationScreenState extends State<AddMedicationScreen> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController dosageController = TextEditingController();
  final TextEditingController frequencyController = TextEditingController();

  DateTime? lastTaken;
  List<Map<String, dynamic>> filteredList = [];
  bool isLoading = false;
  bool isManualEntry = false;
  final String? apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    fetchMedications("");
  }
Future<void> fetchMedications(String query) async {
    setState(() {
      isLoading = true;
    });

    try {
      final token = await AuthService().getAccessToken();
      if (token == null) return;

      final encodedQuery = Uri.encodeComponent(query.trim());
      final url = query.trim().isEmpty
          ? '$apiUrl/medications/search/' // no query param = random meds from OpenFDA
          : '$apiUrl/medications/search/?query=$encodedQuery';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
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


  Future<Map<String, dynamic>> fetchMedicationDetails(String fdaId) async {
    final token = await AuthService().getAccessToken();
    if (token == null) return {};

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/medications/details/?fda_id=$fdaId'),
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

  Future<void> saveMedication(
      String name, String dosage, String frequency, String? fdaId) async {
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
          'fda_id': fdaId,
          'dosage': dosage,
          'frequency': frequency,
          'last_taken': lastTaken?.toIso8601String(),
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Medication saved successfully!")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print("Error saving medication: $e");
    }
  }

void showMedicationInputDialog(String name,
      {String? fdaId, List<String>? dosageForms, String? defaultFrequency}) {
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
                    frequencyController.text, fdaId);
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
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
      final scannedDosage = jsonData['dosage_and_administration'] ?? '';
      final scannedFrequency = jsonData['frequency'] ?? 'Once daily';

      setState(() {
        searchController.text = scannedName;
        nameController.text = scannedName;
        dosageController.text = scannedDosage;
        frequencyController.text = scannedFrequency;
        isManualEntry = true;
      });

      fetchMedications(scannedName);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error scanning medication.")),
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
                                  final details =
                                      await fetchMedicationDetails(med['id']);

                                  showMedicationInputDialog(
                                    med['name'],
                                    fdaId: med['id'], 
                                    dosageForms: [
                                      details['dosage_and_administration'] ?? ""
                                    ],
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
