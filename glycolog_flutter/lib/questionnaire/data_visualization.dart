import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  double thresholdWellness = 3.0;

  @override
  void initState() {
    super.initState();
    _loadPreferredUnit();
    _fetchQuestionnaireData();
  }

  Future<void> _loadPreferredUnit() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _preferredGlucoseUnit = prefs.getString('selectedUnit') ?? 'mg/dL';
    });
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
          _questionnaireData = _normalizeAndFilterData(data);
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

  List<Map<String, dynamic>> _normalizeAndFilterData(List<dynamic> data) {
    List<Map<String, dynamic>> normalizedData = data.map((item) {
      DateTime sessionDate = DateTime.parse(item['date']).toLocal();
      return {
        'date': sessionDate,
        'is_latest': item['is_latest'] ?? false,
        'glucose_check': _normalizeGlucoseList(
            item['glucose_check'] ?? [], _preferredGlucoseUnit),
        'wellness_score': _mapWellnessToScore(item['wellness_score']),
        'exercise_duration': item['exercise_check']?['duration'] ?? 0,
        'sleep_hours': item['sleep_hours'] ?? 0.0,
        'meal_data': {
          'skipped': item['meal_check']?[0]?['skipped_meals']?.length ?? 0,
          'weighted_gi': item['meal_check']?[0]?['weighted_gi'] ?? 0.0,
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
      double level = check['level'] ?? 0.0;
      return _normalizeGlucose(level, unit);
    }).toList();
  }

  double _normalizeGlucose(double level, String unit) {
    return unit == 'mmol/L' ? level * 18 : level;
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
            Navigator.of(context).pushNamed('/home');
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                          _buildThresholdAdjuster(),
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

  Widget _buildThresholdAdjuster() {
    return Column(
      children: [
        const Text(
          'Adjust Wellness Threshold',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Slider(
          value: thresholdWellness,
          min: 1.0,
          max: 5.0,
          divisions: 4,
          label: thresholdWellness.toString(),
          onChanged: (newValue) {
            setState(() {
              thresholdWellness = newValue;
            });
          },
        ),
      ],
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
            Text('Exercise Duration: ${latestData['exercise_duration']} mins'),
            Text('Weighted GI: ${latestData['meal_data']['weighted_gi']}'),
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
        _buildLegendRow([
          {'color': Colors.blue, 'label': 'Glucose Levels'},
          {'color': Colors.green, 'label': 'Wellness Scores'},
        ]),
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
        _buildLegendRow([
          {'color': Colors.orange, 'label': 'Exercise Duration'},
        ]),
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
        SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              barGroups: _questionnaireData.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    // Weighted GI
                    BarChartRodData(
                      toY: data['meal_data']['weighted_gi'],
                      color: Colors.red, 
                    ),
                    // Skipped Meals
                    BarChartRodData(
                      toY: data['meal_data']['skipped'].toDouble(),
                      color: Colors.grey,
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        _buildLegendRow([
          {
            'color': Colors.red, 'label': 'Weighted GI'
          }, 
          {'color': Colors.grey, 'label': 'Skipped Meals'},
        ]),
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
        SizedBox(height: 300, child: _buildRadarChart(averages)),
      ],
    );
  }


  Widget _buildLegendRow(List<Map<String, dynamic>> legends) {
    return Wrap(
      spacing: 10.0,
      runSpacing: 5.0,
      children: legends.map((legend) {
        return ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width / 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 16, height: 16, color: legend['color']),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  legend['label'],
                  style: const TextStyle(overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
        // Glucose Levels Line
        LineChartBarData(
          spots: _questionnaireData.asMap().entries.map((entry) {
            final index = entry.key.toDouble();
            final data = entry.value;
            return FlSpot(index, data['glucose_check'][0]);
          }).toList(),
          isCurved: true,
          color: Colors.blue,
          barWidth: 3,
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                Colors.blue.withOpacity(0.4),
                Colors.blue.withOpacity(0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // Wellness Scores Line
        LineChartBarData(
          spots: _questionnaireData.asMap().entries.map((entry) {
            final index = entry.key.toDouble();
            final data = entry.value;
            return FlSpot(index, data['wellness_score'].toDouble());
          }).toList(),
          isCurved: true,
          color: Colors.green,
          barWidth: 3,
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                Colors.green.withOpacity(0.4),
                Colors.green.withOpacity(0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
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
                toY: data['exercise_duration'].toDouble(), color: Colors.orange)
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
                  toY: data['meal_data']['weighted_gi'].toDouble(),
                  color: Colors.red),
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
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()} hrs',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: _questionnaireData.map((data) {
              return FlSpot(
                data['sleep_hours'], // Sleep duration
                data['wellness_score'].toDouble(), // Wellness score
              );
            }).toList(),
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.2),
            ),
            dotData: FlDotData(show: true),
          ),
        ],
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(
            y: 7, // Recommended minimum sleep
            color: Colors.green,
            strokeWidth: 1,
            dashArray: [4, 4],
            label: HorizontalLineLabel(
              show: true,
              labelResolver: (_) => '7 hrs (Recommended)',
              style: const TextStyle(fontSize: 10, color: Colors.green),
            ),
          ),
        ]),
      ),
    );
  }

Widget _buildTimeSeriesSleepChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _questionnaireData.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  _formatDateTime(_questionnaireData[index]['date']),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          // Sleep Duration
          LineChartBarData(
            spots: _questionnaireData.asMap().entries.map((entry) {
              final index = entry.key.toDouble();
              final data = entry.value;
              return FlSpot(index, data['sleep_hours']);
            }).toList(),
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
          ),
          // Wellness Score
          LineChartBarData(
            spots: _questionnaireData.asMap().entries.map((entry) {
              final index = entry.key.toDouble();
              final data = entry.value;
              return FlSpot(index, data['wellness_score'].toDouble());
            }).toList(),
            isCurved: true,
            color: Colors.green,
            barWidth: 2,
          ),
        ],
      ),
    );
  }


Widget _buildRadarChart(Map<String, double> data) {
    const labels = ["Glucose", "Exercise", "Sleep", "Wellness"];
    const chartScale = 5.0;

    // Normalize data to fit the chart scale (1-5)
    List<RadarEntry> chartData = [
      RadarEntry(value: (data["Glucose"]! / 20).clamp(0, chartScale)),
      RadarEntry(value: (data["Exercise"]! / 120).clamp(0, chartScale)),
      RadarEntry(value: (data["Sleep"]! / 8).clamp(0, chartScale)),
      RadarEntry(value: (data["Wellness"]! / 5).clamp(0, chartScale)),
    ];

    return SizedBox(
      height: 300,
      child: RadarChart(
        RadarChartData(
          radarBorderData: const BorderSide(color: Colors.grey),
          dataSets: [
            RadarDataSet(
              dataEntries: chartData,
              fillColor: Colors.blue.withOpacity(0.4),
              borderColor: Colors.blue,
              borderWidth: 2,
              entryRadius: 2.5,
            ),
          ],
          radarShape: RadarShape.circle,
          titlePositionPercentageOffset: 0.2,
          getTitle: (index, angle) {
            return RadarChartTitle(
              text: labels[index],
              angle: angle,
              positionPercentageOffset: 0.2,
            );
          },
          tickCount: 5,
          ticksTextStyle: const TextStyle(fontSize: 10, color: Colors.grey),
          gridBorderData: BorderSide(color: Colors.grey.withOpacity(0.5)),
        ),
      ),
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
