import 'package:flutter/material.dart';

class EditMedicationScreen extends StatelessWidget {
  final Map<String, dynamic> medication;

  const EditMedicationScreen({super.key, required this.medication});

  @override
  Widget build(BuildContext context) {
    TextEditingController nameController =
        TextEditingController(text: medication['name']);
    TextEditingController dosageController =
        TextEditingController(text: medication['dosage']);
    TextEditingController frequencyController =
        TextEditingController(text: medication['frequency']);
    DateTime? lastTaken = medication['last_taken'] != null
        ? DateTime.parse(medication['last_taken'])
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text("Edit Medication")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
                controller: nameController,
                decoration:
                    const InputDecoration(labelText: "Medication Name")),
            TextField(
                controller: dosageController,
                decoration: const InputDecoration(labelText: "Dosage")),
            TextField(
                controller: frequencyController,
                decoration: const InputDecoration(labelText: "Frequency")),
            ListTile(
              title: const Text("Last Taken"),
              subtitle: Text(lastTaken != null
                  ? lastTaken.toLocal().toString().split(' ')[0]
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
                    lastTaken = pickedDate;
                  }
                },
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () {}, child: const Text("Save Changes")),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child:
                  const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
