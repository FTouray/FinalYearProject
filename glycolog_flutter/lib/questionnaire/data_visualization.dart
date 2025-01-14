import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../services/auth_service.dart';

class QuestionnaireVisualizationScreen extends StatefulWidget {
  const QuestionnaireVisualizationScreen({Key? key}) : super(key: key);

  @override
  _QuestionnaireVisualizationScreenState createState() =>
      _QuestionnaireVisualizationScreenState();
}

class _QuestionnaireVisualizationScreenState
    extends State<QuestionnaireVisualizationScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  List<Map<String, dynamic>> _questionnaireData = [];
  String _preferredGlucoseUnit = 'mg/dL';
  String _selectedRange = "Last 10 Sessions";

  @override
  void initState() {
    super.initState();
    _fetchQuestionnaireData();
  }

  Future<void> _fetchQuestionnaireData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      String? token = await AuthService().getAccessToken();
      if (token == null) {
        throw Exception('User is not authenticated.');
      }

      final response = await http.get(
        Uri.parse(
            'http://192.168.1.12:8000/api/questionnaire/data-visualization/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _questionnaireData = _filterDataByRange(data);
        });
      } else {
        setState(() {
          _hasError = true;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filterDataByRange(List<dynamic> data) {
    List<Map<String, dynamic>> normalizedData = data.map((item) {
      DateTime sessionDate = DateTime.parse(item['date']).toLocal();
      return {
        'date': sessionDate,
        'is_latest': item['is_latest'] ?? false,
        'glucose_check':
            _normalizeGlucoseList(item['glucose_check'], _preferredGlucoseUnit),
        'wellness_score': _mapWellnessToScore(item['wellness_score']),
        'exercise_duration':
            _normalizeDuration(item['exercise_check']['duration'] ?? 0),
        'sleep_hours': item['sleep_hours'] ?? 0.0,
        'meal_data': {
          'high_gi': item['meal_check'][0]['high_gi_food_count'] ?? 0,
          'low_gi': 0,
          'skipped': item['meal_check'][0]['skipped_meals'].length ?? 0,
        },
      };
    }).toList();

    switch (_selectedRange) {
      case "Last 7 Sessions":
        return normalizedData.reversed.take(7).toList();
      case "Last 10 Sessions":
        return normalizedData.reversed.take(10).toList();
      case "Last 30 Days":
        DateTime now = DateTime.now();
        return normalizedData
            .where((entry) =>
                entry['date'].isAfter(now.subtract(Duration(days: 30))))
            .toList();
      case "All Sessions":
        return normalizedData;
      default:
        return normalizedData;
    }
  }

  List<double> _normalizeGlucoseList(List<dynamic> glucoseChecks, String unit) {
    return glucoseChecks.map((check) {
      double level = check['level'];
      return _normalizeGlucose(level, unit);
    }).toList();
  }

  double _normalizeGlucose(double level, String unit) {
    double glucoseInMgDl = unit == 'mmol/L' ? level * 18 : level;
    return glucoseInMgDl;
  }

  double _normalizeDuration(double duration) {
    return duration / 60; // Normalize to hours
  }

  int _mapWellnessToScore(String? feeling) {
    if (feeling == 'good') return 5;
    if (feeling == 'okay') return 3;
    if (feeling == 'bad') return 1;
    return 0;
  }

  String _formatDateTime(DateTime date) {
    return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Questionnaire Data Visualization'),
        backgroundColor: Colors.blue[800],
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () {
            Navigator.of(context).pushNamed('/home'); // Navigate to home screen
          },
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _hasError
              ? const Center(
                  child: Text('Failed to load data. Please try again.',
                      style: TextStyle(color: Colors.red, fontSize: 16)),
                )
              : _questionnaireData.isEmpty
                  ? const Center(
                      child: Text('No data available.',
                          style: TextStyle(fontSize: 16)),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ListView(
                        children: [
                          _buildDropdownFilter(),
                          const SizedBox(height: 20),
                          const Text(
                            'Insights Summary',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          _buildLatestSummary(),
                          const SizedBox(height: 30),
                          _buildLineChartSection(),
                          const SizedBox(height: 30),
                          _buildBarChartSection(),
                          const SizedBox(height: 30),
                          _buildStackedBarChartSection(),
                          const SizedBox(height: 30),
                          _buildScatterPlotSection(),
                          const SizedBox(height: 30),
                          _buildRadarChartSection(),
                          const SizedBox(height: 30),
                          Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.home),
                              label: const Text('Back to Home'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                Navigator.of(context).pushNamed('/home');
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildDropdownFilter() {
    return DropdownButton<String>(
      value: _selectedRange,
      items: const [
        DropdownMenuItem(
            value: "Last 7 Sessions", child: Text("Last 7 Sessions")),
        DropdownMenuItem(
            value: "Last 10 Sessions", child: Text("Last 10 Sessions")),
        DropdownMenuItem(value: "Last 30 Days", child: Text("Last 30 Days")),
        DropdownMenuItem(value: "All Sessions", child: Text("All Sessions")),
      ],
      onChanged: (value) {
        setState(() {
          _selectedRange = value!;
          _fetchQuestionnaireData();
        });
      },
    );
  }

  Widget _buildLatestSummary() {
    final latestData = _questionnaireData.lastWhere((data) => data['is_latest'],
        orElse: () => {});
    if (latestData.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Most Recent Entry Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Date: ${_formatDateTime(latestData['date'])}'),
            Text('Glucose Levels: ${latestData['glucose_check'].join(", ")}'),
            Text('Wellness Score: ${latestData['wellness_score']}'),
            Text('Exercise Duration: ${latestData['exercise_duration']} hrs'),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Glucose Levels vs. Wellness Scores',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SizedBox(height: 300, child: LineChart(_buildLineChartData())),
        const SizedBox(height: 10),
        const Text(
          'Legend:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            _buildLegendItem(Colors.blue, 'Glucose Levels'),
            _buildLegendItem(Colors.green, 'Wellness Scores'),
          ],
        ),
      ],
    );
  }

  Widget _buildBarChartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Exercise Duration vs. Wellness',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SizedBox(height: 300, child: BarChart(_buildBarChartData())),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_buildLegendItem(Colors.orange, 'Exercise Duration')],
        ),
      ],
    );
  }

  Widget _buildStackedBarChartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Meal Composition vs. Wellness',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SizedBox(height: 300, child: _buildMealStackedBarChart()),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(Colors.red, 'High GI'),
            _buildLegendItem(Colors.green, 'Low GI'),
            _buildLegendItem(Colors.grey, 'Skipped Meals'),
          ],
        ),
      ],
    );
  }

  Widget _buildScatterPlotSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sleep Duration vs. Wellness',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SizedBox(height: 300, child: _buildScatterPlotData()),
      ],
    );
  }

  Widget _buildRadarChartSection() {
    Map<String, double> averages = _calculateAverages();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overall Average Comparison',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _buildRadarChart(averages),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 16, height: 16, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }

  LineChartData _buildLineChartData() {
    return LineChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= _questionnaireData.length) {
                return const SizedBox.shrink();
              }
              return Wrap(
                children: [
                  Text(
                    _formatDateTime(_questionnaireData[index]['date']),
                    style: const TextStyle(fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: _questionnaireData.asMap().entries.map((entry) {
            final index = entry.key.toDouble();
            final data = entry.value;
            return FlSpot(index, data['glucose_check'][0]);
          }).toList(),
          isCurved: true,
          color: Colors.blue,
        ),
        LineChartBarData(
          spots: _questionnaireData.asMap().entries.map((entry) {
            final index = entry.key.toDouble();
            final data = entry.value;
            return FlSpot(index, data['wellness_score'].toDouble());
          }).toList(),
          isCurved: true,
          color: Colors.green,
        ),
      ],
    );
  }

  BarChartData _buildBarChartData() {
    return BarChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= _questionnaireData.length) {
                return const SizedBox.shrink();
              }
              return Wrap(
                children: [
                  Text(
                    _formatDateTime(_questionnaireData[index]['date']),
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      barGroups: _questionnaireData.asMap().entries.map((entry) {
        final index = entry.key;
        final data = entry.value;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
                toY: data['exercise_duration'], color: Colors.orange)
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMealStackedBarChart() {
    return BarChart(
      BarChartData(
        barGroups: _questionnaireData.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                  toY: data['meal_data']['high_gi'].toDouble(),
                  color: Colors.red),
              BarChartRodData(
                  toY: data['meal_data']['low_gi'].toDouble(),
                  color: Colors.green),
              BarChartRodData(
                  toY: data['meal_data']['skipped'].toDouble(),
                  color: Colors.grey),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildScatterPlotData() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: _questionnaireData.map((data) {
              double sleepDuration = data['sleep_hours'];
              double wellnessScore = data['wellness_score'].toDouble();
              return FlSpot(sleepDuration, wellnessScore);
            }).toList(),
            isCurved: false,
            color: Colors.blue,
            dotData: FlDotData(show: true),
            barWidth: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildRadarChart(Map<String, double> data) {
    return Center(
      child: Text("Radar Chart Placeholder"),
    );
  }

  Map<String, double> _calculateAverages() {
    double avgGlucose = _questionnaireData
            .map((data) => data['glucose_check'][0])
            .reduce((a, b) => a + b) /
        _questionnaireData.length;
    double avgExercise = _questionnaireData
            .map((data) => data['exercise_duration'])
            .reduce((a, b) => a + b) /
        _questionnaireData.length;
    double avgSleep = _questionnaireData
            .map((data) => data['sleep_hours'])
            .reduce((a, b) => a + b) /
        _questionnaireData.length;
    double avgWellness = _questionnaireData
            .map((data) => data['wellness_score'])
            .reduce((a, b) => a + b) /
        _questionnaireData.length;

    return {
      "Glucose": avgGlucose,
      "Exercise": avgExercise,
      "Sleep": avgSleep,
      "Wellness": avgWellness,
    };
  }
}
