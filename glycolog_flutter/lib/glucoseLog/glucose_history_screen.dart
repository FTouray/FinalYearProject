import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glycolog/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'glucose_detail_screen.dart';
import 'package:glycolog/utils.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

class GlucoseLogHistoryScreen extends StatefulWidget {
  const GlucoseLogHistoryScreen({super.key});

  @override
  GlucoseLogHistoryScreenState createState() =>
      GlucoseLogHistoryScreenState();
}

class GlucoseLogHistoryScreenState extends State<GlucoseLogHistoryScreen> {
  List<Map<String, dynamic>> glucoseLogs = [];
  List<Map<String, dynamic>> filteredLogs = [];
  String measurementUnit = 'mg/dL';
  bool isLoading = true;
  String? errorMessage;

  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _levelFilterController = TextEditingController();
  String _selectedFilterType = 'equal';

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    fetchGlucoseLogs();
  }

  // Method to load user settings from SharedPreferences
  Future<void> _loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      measurementUnit = prefs.getString('selectedUnit') ?? 'mg/dL';
    });
  }

  Future<void> fetchGlucoseLogs() async {
    String? token = await AuthService().getAccessToken();

    if (token != null) {
      try {
        final apiUrl = dotenv.env['API_URL'];
        final response = await http.get(
          Uri.parse('$apiUrl/glucose-log/'), 
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            glucoseLogs = List<Map<String, dynamic>>.from(data['logs'] ?? [])
              ..sort((a, b) => DateTime.parse(b['timestamp'])
                  .compareTo(DateTime.parse(a['timestamp'])));
            if (measurementUnit == 'mmol/L') {
              for (var log in glucoseLogs) {
                log['glucose_level'] = convertToMmolL(log['glucose_level']);
              }
            }
            filteredLogs = glucoseLogs;
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = 'Failed to load glucose logs.';
            isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          errorMessage = 'An error occurred: $e';
          isLoading = false;
        });
      }
    } else {
      setState(() {
        errorMessage = 'No valid token found. Please log in again.';
        isLoading = false;
      });
    }
  }

  // Method to apply filters based on user input
  void _applyFilters() {
    double? filterLevel;
    if (_levelFilterController.text.isNotEmpty) {
      try {
        filterLevel = double.parse(_levelFilterController.text);
        if (measurementUnit == 'mmol/L') {
          filterLevel = convertToMgdL(filterLevel);
        }
      } catch (e) {
        setState(() {
          errorMessage = 'Please enter a valid numeric glucose level.';
        });
        return;
      }
    }

    setState(() {
      filteredLogs = List<Map<String, dynamic>>.from(glucoseLogs).where((log) {
        final logDate = DateTime.parse(log['timestamp']);
        final logLevel = log['glucose_level'];

        bool dateFilter = true;
        if (_startDate != null) {
          dateFilter = logDate.isAfter(_startDate!) ||
              logDate.isAtSameMomentAs(_startDate!);
        }
        if (_endDate != null) {
          dateFilter = dateFilter &&
              (logDate.isBefore(_endDate!.add(const Duration(days: 1))) ||
                  logDate.isAtSameMomentAs(_endDate!));
        }

        bool levelFilter = true;
        if (filterLevel != null) {
          switch (_selectedFilterType) {
            case 'greater':
              levelFilter = logLevel > filterLevel;
              break;
            case 'less':
              levelFilter = logLevel < filterLevel;
              break;
            case 'equal':
            default:
              levelFilter = logLevel == filterLevel;
              break;
          }
        }

        return dateFilter && levelFilter;
      }).toList();
    });
  }

  Future<void> _selectDate(BuildContext context, {bool isStart = true}) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      setState(() {
        if (isStart) {
          _startDate = pickedDate;
        } else {
          _endDate = pickedDate;
        }
      });
      _applyFilters();
    }
  }

  void _clearFilters() {
    setState(() {
      _levelFilterController.clear();
      _selectedFilterType = 'equal';
      _startDate = null;
      _endDate = null;
      filteredLogs = glucoseLogs;
      errorMessage = null;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Glucose Log History'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),

                  const Text(
                    'Glucose Log History',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Glucose Level Filter
                  _buildFilterSection(),

                  const SizedBox(height: 10),

                  // Date Range Filter Section
                  _buildDateFilterSection(),

                  const SizedBox(height: 20),

                  // Apply Filters Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _applyFilters,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          backgroundColor: Colors.blue[800],
                        ),
                        child: const Text('Apply Filters',
                            style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton(
                        onPressed: _clearFilters,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          side: const BorderSide(color: Colors.blue),
                        ),
                        child: const Text('Clear Filters'),
                      ),
                    ],
                  ),


                  const SizedBox(height: 20),


                  // Filtered Glucose Logs
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredLogs.length,
                      itemBuilder: (context, index) {
                        final log = filteredLogs[index];
                        return _buildLogTile(log, context);
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Widget for the glucose level filter section
  Widget _buildFilterSection() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _levelFilterController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Filter by Glucose Level',
              labelStyle: const TextStyle(fontSize: 16, color: Colors.black54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        DropdownButton<String>(
          value: _selectedFilterType,
          onChanged: (String? newValue) {
            setState(() {
              _selectedFilterType = newValue!;
            });
          },
          items: const [
            DropdownMenuItem(value: 'greater', child: Text('>')),
            DropdownMenuItem(value: 'less', child: Text('<')),
            DropdownMenuItem(value: 'equal', child: Text('=')),
          ],
        ),
      ],
    );
  }

  // Widget for the date filter section
  Widget _buildDateFilterSection() {
    return Row(
      children: [
        Expanded(
          child: ListTile(
            title: Text(
              _startDate != null
                  ? 'From: ${DateFormat('yyyy-MM-dd').format(_startDate!)}'
                  : 'From: Select Date',
              style: const TextStyle(color: Colors.black87, fontSize: 16),
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _selectDate(context, isStart: true),
          ),
        ),
        Expanded(
          child: ListTile(
            title: Text(
              _endDate != null
                  ? 'To: ${DateFormat('yyyy-MM-dd').format(_endDate!)}'
                  : 'To: Select Date',
              style: const TextStyle(color: Colors.black87, fontSize: 16),
            ),

            trailing: const Icon(Icons.calendar_today),
            onTap: () => _selectDate(context, isStart: false),
          ),
        ),
      ],
    );
  }

  // Widget for displaying each glucose log
  Widget _buildLogTile(Map<String, dynamic> log, BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      elevation: 4.0,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        title: Text(
          'Glucose Level: ${log['glucose_level']} $measurementUnit',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Date & Time: ${formatTimestamp(log['timestamp'])}',
          style: const TextStyle(fontSize: 16, color: Colors.black54),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LogDetailsScreen(logDetails: log),
            ),
          );
        },
      ),
    );
  }
}
