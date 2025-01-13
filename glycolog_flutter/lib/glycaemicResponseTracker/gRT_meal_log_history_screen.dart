import 'package:Glycolog/glycaemicResponseTracker/gRT_history_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:Glycolog/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:Glycolog/utils.dart';

class MealLogHistoryScreen extends StatefulWidget {
  const MealLogHistoryScreen({super.key});

  @override
  _MealLogHistoryScreenState createState() => _MealLogHistoryScreenState();
}

class _MealLogHistoryScreenState extends State<MealLogHistoryScreen> {
  List<Map<String, dynamic>> mealLogs = [];
  List<Map<String, dynamic>> filteredLogs = [];
  bool isLoading = true;
  String? errorMessage;
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minGI;
  double? _maxGI;

  @override
  void initState() {
    super.initState();
    fetchMealLogs();
  }

  Future<void> fetchMealLogs() async {
    String? token = await AuthService().getAccessToken();
    if (token != null) {
      try {
        final response = await http.get(
           Uri.parse('http://192.168.1.12:8000/api/meal-log/history/'), // Physical Device
          //Uri.parse('http://172.20.10.3:8000/api/meal-log-history/'), // Hotspot
          headers: {
            'Authorization': 'Bearer $token',
          },
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            mealLogs = List<Map<String, dynamic>>.from(data ?? []);
            filteredLogs = mealLogs;
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = 'Failed to load meal logs.';
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

  void _applyFilters() {
    setState(() {
      filteredLogs = mealLogs.where((log) {
        final logDate = DateTime.parse(log['timestamp']);
        bool dateFilter = true;
        if (_startDate != null) {
          dateFilter = logDate.isAfter(_startDate!) ||
              logDate.isAtSameMomentAs(_startDate!);
        }
        if (_endDate != null) {
          dateFilter = dateFilter &&
              (logDate.isBefore(_endDate!) ||
                  logDate.isAtSameMomentAs(_endDate!));
        }
        bool giFilter = true;
        if (_minGI != null) {
          giFilter = giFilter && (log['total_glycaemic_index'] >= _minGI!);
        }
        if (_maxGI != null) {
          giFilter = giFilter && (log['total_glycaemic_index'] <= _maxGI!);
        }

        return dateFilter && giFilter;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Log History'),
        backgroundColor: Colors.blue[800],
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
                    'Meal Log History',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Date Range Filter Section
                  _buildDateFilterSection(),
                  const SizedBox(height: 20),
                   // Total GI Filter Section
                  _buildGIInputSection(),
                  const SizedBox(height: 20),
                  // Apply Filters Button
                  Center(
                    child: ElevatedButton(
                      onPressed: _applyFilters,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 15),
                        backgroundColor: Colors.blue[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: const Text('Apply Filters',
                          style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Filtered Meal Logs
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

  Widget _buildDateFilterSection() {
    return Row(
      children: [
        Expanded(
          child: ListTile(
            title: Text(
              _startDate != null
                  ? 'From: ${_startDate!.toLocal()}'.split(' ')[0]
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
                  ? 'To: ${_endDate!.toLocal()}'.split(' ')[0]
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
            'Meal ID: ${log['user_meal_id']}${log['name'] != null ? ' - ${log['name']}' : ''}', 
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Timestamp: ${formatTimestamp(log['timestamp'])}',
          style: const TextStyle(fontSize: 16, color: Colors.black54),
        ),
        trailing: Text(
          'GI: ${log['total_glycaemic_index']}',
          style: const TextStyle(fontSize: 16, color: Colors.black54),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MealDetailScreen(meal: log),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGIInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filter by Total GI:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Min GI',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _minGI = value.isNotEmpty ? double.tryParse(value) : null;
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Max GI',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _maxGI = value.isNotEmpty ? double.tryParse(value) : null;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
