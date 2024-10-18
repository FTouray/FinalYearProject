import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Glycolog/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'gl_detail_screen.dart';


class GlucoseLogHistoryScreen extends StatefulWidget {
  const GlucoseLogHistoryScreen({super.key});

  @override
  _GlucoseLogHistoryScreenState createState() => _GlucoseLogHistoryScreenState();
}

class _GlucoseLogHistoryScreenState extends State<GlucoseLogHistoryScreen> {
  List<Map<String, dynamic>> glucoseLogs = []; // List to hold glucose log data
  List<Map<String, dynamic>> filteredLogs = []; // List to hold filtered logs
  String measurementUnit = 'mg/dL'; // Default measurement unit
  bool isLoading = true; // To show loading indicator while fetching data
  String? errorMessage; // To hold error messages if any

  DateTime? _startDate; // For filtering by start date
  DateTime? _endDate; // For filtering by end date
  final TextEditingController _levelFilterController = TextEditingController(); // Input for glucose level filter
  String _selectedFilterType = 'equal'; // Filter type (greater, less, or equal)

  @override
  void initState() {
    super.initState();
    _loadUserSettings(); // Load user settings to get the preferred measurement unit
    fetchGlucoseLogs(); // Fetch glucose logs when the screen initializes
  }

  // Fetch user's preferred measurement unit
  Future<void> _loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      measurementUnit = prefs.getString('selectedUnit') ?? 'mg/dL'; // Default to mg/dL
    });
  }

  // Conversion function to convert mg/dL to mmol/L
  double convertToMmolL(double value) {
    return value / 18.01559; // Convert mg/dL to mmol/L
  }

  // Conversion function to convert mmol/L to mg/dL
  double convertToMgdL(double value) {
    return value * 18.01559; // Convert mmol/L to mg/dL
  }

  // Fetch glucose logs from the server
  Future<void> fetchGlucoseLogs() async {
    String? token = await AuthService().getAccessToken(); // Get access token

    if (token != null) {
      try {
        final response = await http.get(
          Uri.parse('http://10.0.2.2:8000/api/glucose-log/'), // Replace with your API endpoint
          headers: {
            'Authorization': 'Bearer $token', // Send token in request header
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            glucoseLogs = List<Map<String, dynamic>>.from(data['logs'] ?? []); // Get logs or an empty list

            // Apply unit conversion to each glucose log based on the user's setting
            if (measurementUnit == 'mmol/L') {
              for (var log in glucoseLogs) {
                log['glucoseLevel'] = convertToMmolL(log['glucoseLevel']);
              }
            }

            filteredLogs = glucoseLogs; // Initially, all logs are displayed
            isLoading = false; // Data has been loaded
          });
        } else {
          // Handle server error
          setState(() {
            errorMessage = 'Failed to load glucose logs.';
            isLoading = false;
          });
        }
      } catch (e) {
        // Handle network or other errors
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

  // Function to validate and filter glucose logs based on user input
  void _applyFilters() {
    double? filterLevel;
    if (_levelFilterController.text.isNotEmpty) {
      try {
        filterLevel = double.parse(_levelFilterController.text);

        // Convert the filter level if necessary
        if (measurementUnit == 'mmol/L') {
          filterLevel = convertToMgdL(filterLevel); // Convert to mg/dL for filtering
        }

      } catch (e) {
        setState(() {
          errorMessage = 'Please enter a valid numeric glucose level.';
        });
        return; // Stop if input is invalid
      }
    }

    setState(() {
      filteredLogs = glucoseLogs.where((log) {
        final logDate = DateTime.parse(log['timestamp']); // Parse timestamp
        final logLevel = log['glucoseLevel'];

        // Filter by date range
        bool dateFilter = true;
        if (_startDate != null) {
          dateFilter = logDate.isAfter(_startDate!) || logDate.isAtSameMomentAs(_startDate!);
        }
        if (_endDate != null) {
          dateFilter = dateFilter && (logDate.isBefore(_endDate!) || logDate.isAtSameMomentAs(_endDate!));
        }

        // Filter by glucose level
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

  // Date Picker
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Glucose Log History'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator()) // Show loading indicator while fetching data
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 20),
                  // Glucose Level Filter Section
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _levelFilterController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Filter by Glucose Level',
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
                  ),

                  const SizedBox(height: 10),

                  // Date Range Filter Section
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: Text(_startDate != null
                              ? 'From: ${_startDate!.toLocal()}'.split(' ')[0]
                              : 'From: Select Date'),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () => _selectDate(context, isStart: true),
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          title: Text(_endDate != null
                              ? 'To: ${_endDate!.toLocal()}'.split(' ')[0]
                              : 'To: Select Date'),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () => _selectDate(context, isStart: false),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  ElevatedButton(
                    onPressed: _applyFilters,
                    child: const Text('Apply Filters'),
                  ),

                  const SizedBox(height: 10),

                  // Filtered Glucose Logs
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredLogs.length,
                      itemBuilder: (context, index) {
                        final log = filteredLogs[index];
                        return ListTile(
                          title: Text(
                            'Glucose Level: ${log['glucoseLevel']} $measurementUnit',
                            style: const TextStyle(fontSize: 16),
                          ),
                          subtitle: Text('Date: ${log['timestamp']}'),
                          onTap: () {
                            // Navigate to log details
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LogDetailsScreen(logDetails: log), // Pass log details
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
