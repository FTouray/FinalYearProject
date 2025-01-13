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

  @override
  void initState() {
    super.initState();
    _fetchQuestionnaireData();
  }

  Future<void> _fetchQuestionnaireData() async {
    try {
       String? token = await AuthService().getAccessToken();
       
      final response = await http.get(
        Uri.parse(
            'http://192.168.1.12:8000/api/questionnaire-visualization-data/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _preferredGlucoseUnit = 'mmol/L'; // Replace with dynamic retrieval
          _questionnaireData = data.map((item) {
            final normalizedData = {
              'date': DateTime.parse(item['date']).toLocal(),
              'glucose_checks': _normalizeGlucoseList(
                  item['glucose_checks'], _preferredGlucoseUnit),
              'wellness_score': _mapWellnessToScore(item['wellness_score']),
              'exercise_duration':
                  _normalizeDuration(item['exercise_check']['duration'] ?? 0),
              'sleep_hours': _normalizeSleepHours(item['sleep_hours'] ?? 0.0),
              'stress_level': _mapStressLevel(item['stress_level'] ?? 'None'),
            };
            return normalizedData;
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
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
    return (glucoseInMgDl - 50) / 250; // Assuming range of 50–300 mg/dL
  }

  double _normalizeDuration(double duration) {
    return duration / 60; // Normalize to hours
  }

  double _normalizeSleepHours(double hours) {
    return hours / 10; // Normalize to scale 0–1
  }

  int _mapWellnessToScore(String? feeling) {
    if (feeling == 'good') return 5;
    if (feeling == 'okay') return 3;
    if (feeling == 'bad') return 1;
    return 0;
  }

  int _mapStressLevel(String level) {
    switch (level.toLowerCase()) {
      case 'none':
        return 0;
      case 'low':
        return 1;
      case 'medium':
        return 2;
      case 'high':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Questionnaire Data Visualization'),
        backgroundColor: Colors.blue[800],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? const Center(child: Text('Failed to load data.'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      const Text(
                        'Glucose Levels vs. Wellness Scores',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 300,
                        child: LineChart(_buildLineChartData()),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Exercise Duration vs. Wellness',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 300,
                        child: BarChart(_buildBarChartData()),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Consolidated View: All Metrics vs. Wellness',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 400,
                        child: _buildConsolidatedGraph(),
                      ),
                      const SizedBox(height: 30),
                      _buildLegend(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLegend() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildLegendItem(Colors.blue, 'Glucose Levels'),
            const SizedBox(width: 20),
            _buildLegendItem(Colors.green, 'Wellness Scores'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildLegendItem(Colors.orange, 'Exercise Duration'),
            const SizedBox(width: 20),
            _buildLegendItem(Colors.purple, 'Sleep Hours'),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          color: color,
        ),
        const SizedBox(width: 5),
        Text(label),
      ],
    );
  }

  LineChartData _buildLineChartData() {
    return LineChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, reservedSize: 30),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= _questionnaireData.length) {
                return const SizedBox.shrink();
              }
              return Text(_formatDate(_questionnaireData[index]['date']));
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey, width: 1),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: _questionnaireData.asMap().entries.map((entry) {
            final index = entry.key.toDouble();
            final data = entry.value;
            return FlSpot(index, data['glucose_checks'][0]);
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
          sideTitles: SideTitles(showTitles: true, reservedSize: 30),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= _questionnaireData.length) {
                return const SizedBox.shrink();
              }
              return Text(_formatDate(_questionnaireData[index]['date']));
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey, width: 1),
      ),
      barGroups: _questionnaireData.asMap().entries.map((entry) {
        final index = entry.key;
        final data = entry.value;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: data['exercise_duration'],
              color: Colors.orange,
            ),
          ],
        );
      }).toList(),
    );
  }

  LineChart _buildConsolidatedGraph() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 30),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _questionnaireData.length) {
                  return const SizedBox.shrink();
                }
                return Text(_formatDate(_questionnaireData[index]['date']));
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey, width: 1),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: _questionnaireData.asMap().entries.map((entry) {
              final index = entry.key.toDouble();
              final data = entry.value;
              return FlSpot(index, data['wellness_score'].toDouble());
            }).toList(),
            isCurved: true,
            color: Colors.green,
          ),
          LineChartBarData(
            spots: _questionnaireData.asMap().entries.map((entry) {
              final index = entry.key.toDouble();
              final data = entry.value;
              return FlSpot(index, data['glucose_checks'][0]);
            }).toList(),
            isCurved: true,
            color: Colors.blue,
          ),
          LineChartBarData(
            spots: _questionnaireData.asMap().entries.map((entry) {
              final index = entry.key.toDouble();
              final data = entry.value;
              return FlSpot(index, data['sleep_hours']);
            }).toList(),
            isCurved: true,
            color: Colors.purple,
          ),
          LineChartBarData(
            spots: _questionnaireData.asMap().entries.map((entry) {
              final index = entry.key.toDouble();
              final data = entry.value;
              return FlSpot(index, data['exercise_duration']);
            }).toList(),
            isCurved: true,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}
