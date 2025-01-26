import 'package:Glycolog/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class InsightsGraphScreen extends StatefulWidget {
  const InsightsGraphScreen({Key? key}) : super(key: key);

  @override
  _InsightsGraphScreenState createState() => _InsightsGraphScreenState();
}

class _InsightsGraphScreenState extends State<InsightsGraphScreen> {
  List<FlSpot> glucoseSpots = [];
  List<FlSpot> wellnessSpots = [];
  List<Map<String, dynamic>> highGlucoseMarkers = [];
  List<Map<String, dynamic>> lowGlucoseMarkers = [];
  double? targetMin;
  double? targetMax;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchGraphData();
  }

  Future<void> fetchGraphData() async {
    String? token = await AuthService().getAccessToken();

    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.11:8000/api/insights-graph/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          glucoseSpots = data['glucose_points']
              .map<FlSpot>((point) => FlSpot(
                  DateTime.parse(point['date'])
                      .millisecondsSinceEpoch
                      .toDouble(),
                  point['value']))
              .toList();
          wellnessSpots = data['wellness_points']
              .map<FlSpot>((point) => FlSpot(
                  DateTime.parse(point['date'])
                      .millisecondsSinceEpoch
                      .toDouble(),
                  point['value']))
              .toList();
          highGlucoseMarkers = data['high_glucose_events'];
          lowGlucoseMarkers = data['low_glucose_events'];
          targetMin = data['target_min'];
          targetMax = data['target_max'];
          _isLoading = false;
        });
      } else {
        print("Error: ${response.statusCode}");
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights Graphs'),
        backgroundColor: Colors.blue[800],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (glucoseSpots.isEmpty && wellnessSpots.isEmpty)
              ? _buildNoDataMessage()
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildGraphCard(
                          title: "Glucose Levels vs. Wellness Level",
                          xLabel: "Dates",
                          yLabel: "Values",
                          spots1: glucoseSpots,
                          spots2: wellnessSpots,
                          color1: Colors.red,
                          color2: Colors.blue,
                          targetMin: targetMin,
                          targetMax: targetMax,
                        ),
                        const SizedBox(height: 20),
                        _buildMarkerSection(
                          title: "High Glucose Events",
                          markers: highGlucoseMarkers,
                        ),
                        const SizedBox(height: 20),
                        _buildMarkerSection(
                          title: "Low Glucose Events",
                          markers: lowGlucoseMarkers,
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildNoDataMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          "There is no information recorded to provide insights at this time.",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildGraphCard({
    required String title,
    required String xLabel,
    required String yLabel,
    required List<FlSpot> spots1,
    required List<FlSpot> spots2,
    required Color color1,
    required Color color2,
    double? targetMin,
    double? targetMax,
  }) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final date = DateTime.fromMillisecondsSinceEpoch(
                              value.toInt());
                          return Text("${date.month}/${date.day}");
                        },
                        reservedSize: 22,
                      ),
                      axisNameWidget: Text(xLabel),
                      axisNameSize: 16,
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                      axisNameWidget: Text(yLabel),
                      axisNameSize: 16,
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots1,
                      isCurved: true,
                      barWidth: 2,
                      color: color1,
                      belowBarData: BarAreaData(show: false),
                    ),
                    LineChartBarData(
                      spots: spots2,
                      isCurved: true,
                      barWidth: 2,
                      color: color2,
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      if (targetMin != null)
                        HorizontalLine(
                          y: targetMin,
                          color: Colors.green,
                          strokeWidth: 1.5,
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.centerLeft,
                            labelResolver: (_) => 'Target Min',
                          ),
                        ),
                      if (targetMax != null)
                        HorizontalLine(
                          y: targetMax,
                          color: Colors.red,
                          strokeWidth: 1.5,
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.centerLeft,
                            labelResolver: (_) => 'Target Max',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkerSection({
    required String title,
    required List<Map<String, dynamic>> markers,
  }) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            ...markers.map((event) =>
                Text("Date: ${event['date']}, Level: ${event['value']}")),
          ],
        ),
      ),
    );
  }
}
