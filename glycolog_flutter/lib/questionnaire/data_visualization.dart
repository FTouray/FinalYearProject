import 'package:glycolog/utils.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class QuestionnaireVisualizationScreen extends StatefulWidget {
  const QuestionnaireVisualizationScreen({super.key});

  @override
  QuestionnaireVisualizationScreenState createState() =>
      QuestionnaireVisualizationScreenState();
}

class QuestionnaireVisualizationScreenState
    extends State<QuestionnaireVisualizationScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  List<Map<String, dynamic>> _questionnaireData = [];
  String _preferredGlucoseUnit = 'mg/dL';
  String _selectedRange = "Last 10 Sessions";
  double thresholdWellness = 3.0;
  final String? apiUrl = dotenv.env['API_URL']; 

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

      // Include range as query parameter
      String rangeQuery = _mapRangeToQueryParam(_selectedRange);
      final response = await http.get(
        Uri.parse(
            '$apiUrl/questionnaire/data-visualization/?range=$rangeQuery'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        try {
          final List<dynamic> data = jsonDecode(response.body);
          setState(() {
            _questionnaireData = _normalizeAndFilterData(data);
          });
        } catch (e, stack) {
          print('❌ Parsing error: $e');
          print(stack);
          setState(() {
            _hasError = true;
          });
        }
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

// Helper function to map dropdown selection to query parameters
  String _mapRangeToQueryParam(String range) {
    switch (range) {
      case "Last 7 Sessions":
        return "last_7";
      case "Last 10 Sessions":
        return "last_10";
      case "Last 30 Days":
        return "last_30_days";
      case "All Sessions":
      default:
        return "all";
    }
  }

  List<Map<String, dynamic>> _normalizeAndFilterData(List<dynamic> data) {
    return data.map((item) {
      DateTime sessionDate = DateTime.parse(item['date']).toLocal();
      return {
        'session_id': item['session_id'],
        'date': sessionDate,
        'is_latest': item['is_latest'] ?? false,
        'glucose_check': _normalizeGlucoseList(
            item['glucose_check'] ?? [], _preferredGlucoseUnit),
        'wellness_score': _mapWellnessToScore(item['feeling_check']),
        'exercise_type':
            item['exercise_check']?.map((e) => e['exercise_type'])?.toList() ??
                [],
        'exercise_intensity': item['exercise_check']
                ?.map((e) => e['exercise_intensity'])
                ?.toList() ??
            [],
        'exercise_duration': (item['exercise_check'] as List?)
                ?.map((e) => e['exercise_duration'] ?? 0)
                .fold<int>(0, (a, b) => a + (b as int)) ??
            0,
        'meal_data': {
          'skipped': (item['meal_check'] as List?)?.fold(0,
                  (sum, meal) => sum + ((meal['skipped_meals']?.length ?? 0) as int)) ??
              0,
          'weighted_gi': (item['meal_check'] as List?)?.fold(
                  0.0, (sum, meal) => sum + (meal['weighted_gi'] ?? 0.0)) ??
              0.0,
        },
        'symptoms': (item['symptom_check'] as List<dynamic>?)
                ?.expand((symptomCheck) =>
                    (symptomCheck['symptoms'] as List<dynamic>? ?? []))
                .toList() ??
            [],
        'sleep_hours': (item['symptom_check'] as List?)
                ?.map((e) => e['sleep_hours'] ?? 0.0)
                .fold(0.0, (a, b) => a + b) ??
            0.0,
      };
    }).toList();
  }

  List<double> _normalizeGlucoseList(List<dynamic> glucoseChecks, String unit) {
    return glucoseChecks.map((check) {
      double level = check['glucose_level'] ?? 0.0;
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
    final DateFormat formatter = DateFormat('dd/MM/yyyy HH:mm:ss');
    return formatter.format(date);
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
                          const SizedBox(height: 40),
                          _buildLineChartSection(),
                          const SizedBox(height: 45),
                          _buildBarChartSection(),
                          const SizedBox(height: 45),
                          _buildStackedBarChartSection(),
                          const SizedBox(height: 45),
                          _buildLineChartSleepSection(),
                          const SizedBox(height: 45),
                          _buildSymptomGroupedBarChart(),
                          const SizedBox(height: 45),
                          _buildComprehensiveChartSection(),
                          const SizedBox(height: 45),
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
            Text('Exercise Duration: ${latestData['exercise_duration']} mins'),
            Text('Weighted GI: ${latestData['meal_data']['weighted_gi']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChartSection() {
    final double dynamicWidth =
        _questionnaireData.length * 60.0; // Adjust width based on session count
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Glucose Levels',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width:
                dynamicWidth.clamp(300.0, 1200.0), // Minimum and maximum width
            height: 300,
            child: LineChart(_buildLineChartData()),
          ),
        ),
        const SizedBox(height: 10),
        _buildLegendRow([
          {'color': Colors.blue, 'label': 'Glucose Levels'},
          {'color': Colors.green, 'label': 'Wellness Scores'},
        ]),
      ],
    );
  }

  Widget _buildBarChartSection() {
    final double dynamicWidth =
        _questionnaireData.length * 60.0; // Adjust width dynamically
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Exercise',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width:
                dynamicWidth.clamp(300.0, 1200.0), // Minimum and maximum width
            height: 300,
            child: BarChart(_buildBarChartData()),
          ),
        ),
        _buildLegendRow([
          {'color': Colors.orange, 'label': 'Exercise Duration'},
        ]),
      ],
    );
  }

  Widget _buildStackedBarChartSection() {
    final double dynamicWidth =
        _questionnaireData.length * 60.0; // Adjust width dynamically
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Meal Composition',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width:
                dynamicWidth.clamp(300.0, 1200.0), // Minimum and maximum width
            height: 300,
            child: BarChart(
                _buildMealBarChartData()), // Refactored stacked bar chart
          ),
        ),
        _buildLegendRow([
          {'color': Colors.red, 'label': 'Weighted GI'},
          {'color': Colors.grey, 'label': 'Skipped Meals'},
        ]),
      ],
    );
  }

  Widget _buildLineChartSleepSection() {
    final double dynamicWidth =
        _questionnaireData.length * 60.0; // Adjust width dynamically
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sleep vs Wellness',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width:
                dynamicWidth.clamp(300.0, 1200.0), // Minimum and maximum width
            height: 300,
            child: LineChart(_buildLineChartSleepVsWellnessData()),
          ),
        ),
      ],
    );
  }

  Widget _buildComprehensiveChartSection() {
    final double dynamicWidth =
        _questionnaireData.length * 60.0; // Adjust width dynamically
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comprehensive Chart',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width:
                dynamicWidth.clamp(300.0, 1200.0), // Minimum and maximum width
            height: 300,
            child: LineChart(_buildComprehensiveChartData()),
          ),
        ),
        const SizedBox(height: 10),
        _buildLegendRow([
          {'color': Colors.red, 'label': 'Glucose Levels'},
          {'color': Colors.blue, 'label': 'Sleep Hours'},
          {'color': Colors.green, 'label': 'Exercise Duration'},
          {'color': Colors.orange, 'label': 'Meal Weighted GI'},
        ]),
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
    // Calculate the maximum Y values dynamically with padding
    final glucoseValues = _questionnaireData
        .where((data) =>
            data['glucose_check'] != null && data['glucose_check'].isNotEmpty)
        .map((data) => (data['glucose_check'][0] ?? 0.0).toDouble())
        .toList();

    final maxGlucoseLevel = glucoseValues.isNotEmpty
        ? glucoseValues.reduce((a, b) => a > b ? a : b)
        : 0.0;

    final maxY = (maxGlucoseLevel * 1.2).ceil(); // Add 20% padding
    final interval = (maxY / 5).ceil(); // Divide Y-axis into 5 even intervals

    return LineChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: interval.toDouble(), // Set fixed intervals for the y-axis
            getTitlesWidget: (value, meta) {
              return Text(
                '${value.toInt()}',
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
          axisNameWidget: const RotatedBox(
            quarterTurns: 1, // Rotate the title vertically
            child: Text(
              'Glucose Level',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
          axisNameSize: 20, // Space for the y-axis title
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: 1, // Show every session
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= _questionnaireData.length) {
                return const SizedBox.shrink();
              }

              final sessionId = _questionnaireData[index]['session_id'];

              return Transform.translate(
                offset: const Offset(0, 8),
                child: Transform.rotate(
                  angle: 0, // No rotation
                  child: Text(
                    'S$sessionId',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              );
            },
          ),
          axisNameWidget: const Padding(
            padding:
                EdgeInsets.only(top: 16), // Add space between labels and title
            child: Text(
              'Questionnaire Sessions',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          axisNameSize: 20, // Space for the x-axis title
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots:
              _questionnaireData.reversed.toList().asMap().entries.map((entry) {
            final index = entry.key.toDouble();
             final glucoseList = entry.value['glucose_check'] ?? [];
            final value =
                glucoseList.isNotEmpty ? glucoseList[0].toDouble() : 0.0;
            return FlSpot(index, value);
          }).toList(),
          isCurved: true,
          color: Colors.blue,
          barWidth: 3,
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                Colors.blue.withValues(alpha: 0.4),
                Colors.blue.withValues(alpha: 0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
      minY: 0.0,
      maxY: maxY.toDouble(), // Set dynamic max Y value
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          tooltipRoundedRadius: 8,
          tooltipBorder:
              BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1),
          tooltipMargin: 16,
          getTooltipColor: (touchedSpot) => Colors.grey.withValues(alpha: 0.8),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final index = spot.spotIndex;
              final data = _questionnaireData[index];
              final timestamp = data['date'].toString();
              final formattedDate = formatTimestamp(timestamp);
              final glucoseLevel = data['glucose_check'][0];
              final sessionId = data['session_id'];

              return LineTooltipItem(
                'Session $sessionId\n'
                'Glucose: $glucoseLevel $_preferredGlucoseUnit\n'
                'Date & Time: $formattedDate',
                const TextStyle(color: Colors.white),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  BarChartData _buildBarChartData() {
    // Calculate the maximum Y value dynamically with padding
    final maxExerciseDuration = _questionnaireData
        .map((data) => data['exercise_duration'])
        .reduce((a, b) => a > b ? a : b);
    final maxY =
        (maxExerciseDuration * 1.2).ceil(); // Add 20% padding for visualization
    final interval = (maxY / 5).ceil(); // Divide Y-axis into 5 even intervals

    return BarChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: interval.toDouble(), // Set fixed intervals for the y-axis
            getTitlesWidget: (value, meta) {
              // Display y-axis labels for even intervals
              return Text(
                '${value.toInt()} mins',
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
          axisNameWidget: const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: RotatedBox(
              quarterTurns: 1,
              child: Text(
                'Exercise Duration (mins)',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          axisNameSize: 20,
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: 1, // Show each session label
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= _questionnaireData.length) {
                return const SizedBox.shrink();
              }
              final sessionId = _questionnaireData[index]['session_id'];
              return Text(
                'S$sessionId',
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
          axisNameWidget: const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Questionnaire Sessions',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          axisNameSize: 30,
        ),
      ),
      barGroups: _questionnaireData.asMap().entries.map((entry) {
        final index = entry.key;
        final data = entry.value;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: data['exercise_duration'].toDouble(),
              color: Colors.orange,
            ),
          ],
          showingTooltipIndicators: [], // Disable tooltips by default
        );
      }).toList(),
      maxY: maxY.toDouble(), // Set dynamic max Y value
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (touchedSpot) => Colors.blueGrey.withValues(alpha: 0.8),
          tooltipPadding: const EdgeInsets.all(8),
          tooltipMargin: 8,
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final data = _questionnaireData[groupIndex];
            final exerciseType = data['exercise_type'][0] ?? 'Unknown';
            final intensity = data['exercise_intensity'][0] ?? 'Unknown';
            final duration = data['exercise_duration'] ?? 0.0;

            return BarTooltipItem(
              'Session ${data['session_id']}\n'
              'Type: $exerciseType\n'
              'Intensity: $intensity\n'
              'Duration: ${duration.toStringAsFixed(1)}',
              const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
        touchCallback: (event, response) {
          // Debugging or additional actions on touch can be added here
          if (event.isInterestedForInteractions &&
              response != null &&
              response.spot != null) {
            debugPrint(
                'Touched bar index: ${response.spot!.touchedBarGroupIndex}');
          }
        },
        allowTouchBarBackDraw:
            false, // Ensure background redraw isn't persistent
      ),
    );
  }

  BarChartData _buildMealBarChartData() {
    // Calculate maximum y value with padding
    final maxWeightedGI = _questionnaireData
        .map((data) => data['meal_data']['weighted_gi'])
        .reduce((a, b) => a > b ? a : b);
    final maxSkippedMeals = _questionnaireData
        .map((data) => data['meal_data']['skipped'])
        .reduce((a, b) => a > b ? a : b);
    final maxY =
        (maxWeightedGI > maxSkippedMeals ? maxWeightedGI : maxSkippedMeals) *
            1.2; // Add 20% padding
    final interval =
        (maxY / 5).ceilToDouble(); // Divide y-axis into 5 even intervals

    return BarChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: interval.toDouble(), // Set fixed intervals
            getTitlesWidget: (value, meta) {
              // Display y-axis labels for even intervals
              return Text(
                '${value.toInt()}',
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
          axisNameWidget: const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: RotatedBox(
              quarterTurns: 1,
              child: Text(
                'GI',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          axisNameSize: 20,
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= _questionnaireData.length) {
                return const SizedBox.shrink();
              }
              final sessionId = _questionnaireData[index]['session_id'];
              return Text(
                'S$sessionId',
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
          axisNameWidget: const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Questionnaire Sessions',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          axisNameSize: 30,
        ),
      ),
      barGroups: _questionnaireData.asMap().entries.map((entry) {
        final index = entry.key;
        final data = entry.value;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: data['meal_data']['weighted_gi'].toDouble(),
              color: Colors.red,
            ),
            BarChartRodData(
              toY: data['meal_data']['skipped'].toDouble(),
              color: Colors.grey,
            ),
          ],
          showingTooltipIndicators: [], // Disable tooltips by default
        );
      }).toList(),
      maxY: maxY, // Dynamically calculated max Y
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (touchedSpot) => Colors.blueGrey.withValues(alpha: 0.8),
          tooltipPadding: const EdgeInsets.all(8),
          tooltipMargin: 8,
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final data = _questionnaireData[groupIndex];
            final weightedGi =
                data['meal_data']['weighted_gi'].toStringAsFixed(1);
            final skippedMeals = data['meal_data']['skipped'];
            final date = _formatDateTime(data['date']);

            return BarTooltipItem(
              'Session ${data['session_id']}\n'
              'Date: $date\n'
              'Weighted GI: $weightedGi\n'
              'Skipped Meals: $skippedMeals',
              const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
        touchCallback: (event, response) {
          if (event.isInterestedForInteractions &&
              response != null &&
              response.spot != null) {
            final index = response.spot!.touchedBarGroupIndex;
            final data = _questionnaireData[index];

            // Handle the touch event for debugging or user interactions
            debugPrint(
                'Touched bar index: $index, Session: ${data['session_id']}');
          }
        },
        allowTouchBarBackDraw: false,
      ),
    );
  }

  LineChartData _buildLineChartSleepVsWellnessData() {
    // Calculate the maximum sleep hours dynamically with padding
    final maxSleepHours = _questionnaireData
        .map((data) => data['sleep_hours'] ?? 0.0)
        .reduce((a, b) => a > b ? a : b);

    // Find the maximum y-axis value and adjust it for cleaner intervals
    final maxY =
        ((maxSleepHours * 1.2).ceil() / 2).ceil() * 2; // Round to nearest 2
    final yInterval = (maxY / 5).ceil(); // Divide y-axis into 5 intervals

    return LineChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: yInterval.toDouble(), // Set interval dynamically
            getTitlesWidget: (value, meta) {
              return Text(
                '${value.toInt()} hrs',
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
          axisNameWidget: const RotatedBox(
            quarterTurns: 1,
            child: Text(
              'Hours Slept',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
          axisNameSize: 20,
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: 1, // Show every session
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= _questionnaireData.length) {
                return const SizedBox.shrink();
              }

              final sessionId = _questionnaireData[index]['session_id'];
              return Transform.translate(
                offset: const Offset(0, 8),
                child: Transform.rotate(
                  angle: 0,
                  child: Text(
                    'S$sessionId',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              );
            },
          ),
          axisNameWidget: const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Questionnaire Sessions',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          axisNameSize: 30,
        ),
      ),
      minY: 0.0,
      maxY: maxY.toDouble(), // Dynamically calculated max Y value
      lineBarsData: [
        // Sleep hours line
        LineChartBarData(
          spots: _questionnaireData.asMap().entries.map((entry) {
            final index = entry.key.toDouble();
            final data = entry.value;
            return FlSpot(index, data['sleep_hours'] ?? 0.0);
          }).toList(),
          isCurved: true,
          color: Colors.blue,
          barWidth: 3,
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                Colors.blue.withValues(alpha: 0.4),
                Colors.blue.withValues(alpha: 0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        // Optional: If needed, add another data series (like wellness scores)
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          tooltipRoundedRadius: 8,
          tooltipBorder:
              BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1),
          tooltipMargin: 16,
          getTooltipColor: (touchedSpot) => Colors.grey.withValues(alpha: 0.8),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final index = spot.spotIndex;
              final data = _questionnaireData[index];
              final sessionId = data['session_id'];
              final sleepHours = data['sleep_hours'] ?? 0.0;

              return LineTooltipItem(
                'Session $sessionId\n'
                'Sleep Hours: ${sleepHours.toStringAsFixed(1)}',
                const TextStyle(color: Colors.white),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  LineChartData _buildComprehensiveChartData() {
    final maxGlucoseLevel = _questionnaireData
        .map((data) =>
            (data['glucose_check'] != null && data['glucose_check'].isNotEmpty)
                ? data['glucose_check'][0].toDouble()
                : 0.0)
        .reduce((a, b) => a > b ? a : b);

    final maxSleepHours = _questionnaireData
        .map((data) => data['sleep_hours']?.toDouble() ?? 0.0)
        .reduce((a, b) => a > b ? a : b);

    final maxExerciseDuration = _questionnaireData
        .map((data) => data['exercise_duration']?.toDouble() ?? 0.0)
        .reduce((a, b) => a > b ? a : b);

    final maxMealData = _questionnaireData
        .map((data) => data['meal_data']?['weighted_gi']?.toDouble() ?? 0.0)
        .reduce((a, b) => a > b ? a : b);

    final maxY = ([
              maxGlucoseLevel,
              maxSleepHours,
              maxExerciseDuration,
              maxMealData
            ].reduce((a, b) => a > b ? a : b) *
            1.2)
        .ceil()
        .toDouble();

    final interval = (maxY / 5).ceil().toDouble();

    return LineChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: interval,
            getTitlesWidget: (value, meta) {
              return Text(
                '${value.toInt()}',
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
          axisNameWidget: const RotatedBox(
            quarterTurns: 1,
            child: Text(
              'Values',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          axisNameSize: 20,
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= _questionnaireData.length) {
                return const SizedBox.shrink();
              }
              return Text(
                'S${_questionnaireData[index]['session_id']}',
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
          axisNameWidget: const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Questionnaire Sessions',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          axisNameSize: 30,
        ),
      ),
      minY: 0.0,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: _questionnaireData.asMap().entries.map((entry) {
            final index = entry.key.toDouble();
            final glucoseValue = (entry.value['glucose_check'] != null &&
                    entry.value['glucose_check'].isNotEmpty)
                ? entry.value['glucose_check'][0].toDouble()
                : 0.0;
            return FlSpot(index, glucoseValue);
          }).toList(),
          isCurved: true,
          color: Colors.red,
          barWidth: 3,
          dotData: FlDotData(show: true),
        ),
        LineChartBarData(
          spots: _questionnaireData.asMap().entries.map((entry) {
            final index = entry.key.toDouble();
            final sleepValue = entry.value['sleep_hours']?.toDouble() ?? 0.0;
            return FlSpot(index, sleepValue);
          }).toList(),
          isCurved: true,
          color: Colors.blue,
          barWidth: 3,
          dotData: FlDotData(show: true),
        ),
        LineChartBarData(
          spots: _questionnaireData.asMap().entries.map((entry) {
            final index = entry.key.toDouble();
            final exerciseValue =
                entry.value['exercise_duration']?.toDouble() ?? 0.0;
            return FlSpot(index, exerciseValue);
          }).toList(),
          isCurved: true,
          color: Colors.green,
          barWidth: 3,
          dotData: FlDotData(show: true),
        ),
        LineChartBarData(
          spots: _questionnaireData.asMap().entries.map((entry) {
            final index = entry.key.toDouble();
            final mealValue =
                entry.value['meal_data']?['weighted_gi']?.toDouble() ?? 0.0;
            return FlSpot(index, mealValue);
          }).toList(),
          isCurved: true,
          color: Colors.orange,
          barWidth: 3,
          dotData: FlDotData(show: true),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipPadding: const EdgeInsets.all(8),
          tooltipMargin: 8,
          getTooltipItems: (spots) {
            return spots.map((spot) {
              final dataIndex = spot.spotIndex;
              final data = _questionnaireData[dataIndex];
              return LineTooltipItem(
                'Session ${data['session_id']}\n'
                'Glucose: ${data['glucose_check']?[0] ?? 'N/A'}\n'
                'Sleep: ${data['sleep_hours']?.toStringAsFixed(1) ?? 'N/A'} hrs\n'
                'Exercise: ${data['exercise_duration']?.toStringAsFixed(1) ?? 'N/A'} mins\n'
                'Meal GI: ${data['meal_data']?['weighted_gi']?.toStringAsFixed(1) ?? 'N/A'}',
                const TextStyle(color: Colors.white),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildSymptomGroupedBarChart() {
    // Extract unique symptoms across all sessions
    final List<String> symptomNames = _questionnaireData
        .expand((session) => session['symptoms'])
        .map<String>((symptom) => symptom['symptom'] as String)
        .toSet()
        .toList();

    final double barWidth = 8.0; // Width of individual bars
    final double sessionSpacing = 20.0; // Space between sessions

    // Generate bar groups dynamically
    final List<BarChartGroupData> barGroups =
        _questionnaireData.asMap().entries.map((entry) {
      final sessionIndex = entry.key;
      final sessionData = entry.value;

      // Create bars only for symptoms in this session
      final List<BarChartRodData> bars = symptomNames.map((symptomName) {
        final symptomData = sessionData['symptoms'].firstWhere(
            (symptom) => symptom['symptom'] == symptomName,
            orElse: () => null);

        final severity = symptomData != null
            ? (symptomData['severity'] as num).toDouble()
            : 0.0;

        return BarChartRodData(
          toY: severity,
          width: barWidth,
          color: _getSymptomColor(symptomName),
        );
      }).toList();

      return BarChartGroupData(
        x: sessionIndex,
        barsSpace: 0, // No spacing between bars within the same session
        barRods: bars.where((bar) => bar.toY > 0).toList(), // Remove empty bars
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Symptom Severity Patterns Across Sessions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: _questionnaireData.length *
                (symptomNames.length * barWidth + sessionSpacing),
            height: 350,
            child: BarChart(
              BarChartData(
                barGroups: barGroups,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    axisNameWidget: const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: Text(
                        'Severity',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    axisNameSize: 20,
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final sessionIndex = value.toInt();
                        return sessionIndex < _questionnaireData.length
                            ? Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  'S${_questionnaireData[sessionIndex]['session_id']}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              )
                            : const SizedBox.shrink();
                      },
                    ),
                    axisNameWidget: const Padding(
                      padding: EdgeInsets.only(top: 12.0),
                      child: Text(
                        'Questionnaire Sessions',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    axisNameSize: 20,
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  verticalInterval: 1,
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (touchedSpot) =>
                        Colors.blueGrey.withValues(alpha: 0.8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final symptomName = symptomNames[rodIndex];
                      return BarTooltipItem(
                        '$symptomName\nSeverity: ${rod.toY.toInt()}',
                        const TextStyle(color: Colors.white),
                      );
                    },
                  ),
                ),
                maxY: 5, // Maximum severity level
                alignment: BarChartAlignment.spaceAround,
                groupsSpace: sessionSpacing, // Space between sessions
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildSymptomLegend(symptomNames),
      ],
    );
  }

  Widget _buildSymptomLegend(List<String> symptomNames) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: symptomNames.map((symptom) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              color: _getSymptomColor(symptom),
            ),
            const SizedBox(width: 5),
            Text(
              symptom,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      }).toList(),
    );
  }

  Color _getSymptomColor(String symptom) {
    const Map<String, Color> symptomColors = {
      'Fatigue': Colors.blue,
      'Headaches': Colors.red,
      'Dizziness': Colors.green,
      'Thirst': Colors.orange,
      'Nausea': Colors.purple,
      'Blurred Vision': Colors.teal,
      'Irritability': Colors.pink,
      'Sweating': Colors.yellow,
      'Frequent Urination': Colors.brown,
      'Dry Mouth': Colors.indigo,
      'Slow Wound Healing': Colors.cyan,
      'Weight Loss': Colors.lime,
      'Increased Hunger': Colors.amber,
      'Shakiness': Colors.deepPurple,
      'Hunger': Colors.lightBlue,
      'Fast Heartbeat': Colors.deepOrange,
    };
    return symptomColors[symptom] ??
        Colors.grey; // Default to grey if not listed
  }
}
