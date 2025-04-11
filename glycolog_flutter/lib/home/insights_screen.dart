import 'dart:convert';
import 'package:Glycolog/utils.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:Glycolog/services/auth_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  Map<String, dynamic>? insightsData;
  bool isLoading = true;
  final String? apiUrl = dotenv.env['API_URL'];
  String _selectedUnit = 'mg/dL';

  @override
  void initState() {
    super.initState();
    _loadUnitAndFetchInsights();
  }

  Future<void> _loadUnitAndFetchInsights() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedUnit = prefs.getString('selectedUnit') ?? 'mg/dL';
    await fetchInsights();
  }

  Future<void> fetchInsights() async {
    final token = await AuthService().getAccessToken();
    if (token == null) return;

    try {
      final summaryRes = await http.get(
        Uri.parse('$apiUrl/insights/summary/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final trendRes = await http.get(
        Uri.parse('$apiUrl/health/trends/weekly/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (summaryRes.statusCode == 200 && trendRes.statusCode == 200) {
        setState(() {
          insightsData = {
            ...json.decode(summaryRes.body),
            "trend": json.decode(trendRes.body)['trend'],
          };
          isLoading = false;
        });
      } else {
        print("Failed to load insights.");
      }
    } catch (e) {
      print("Error fetching insights: $e");
    }
  }

  Future<void> generatePdf() async {
    final pdf = pw.Document();
    final trend = insightsData!['trend'];
    final avgGlucose = insightsData?['glucose']?['average']?.toDouble();
    final aiInsight = insightsData?['ai_insight'] ?? "No insights available.";

    final formattedGlucose = await formatGlucoseDynamic(avgGlucose);

    print("AI_INSIGHT: $aiInsight");

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Text("🧠 Personal Insights Summary",
              style:
                  pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.Text("Generated: ${DateTime.now().toLocal()}",
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
          pw.SizedBox(height: 20),
          pw.Text("📊 Health Trend", style: pw.TextStyle(fontSize: 18)),
          pw.Text("Glucose Avg: $formattedGlucose $_selectedUnit"),
          pw.Text("Steps: ${trend['avg_steps']}"),
          pw.Text("Sleep: ${trend['avg_sleep_hours']} hrs"),
          pw.Text("Heart Rate: ${trend['avg_heart_rate']} bpm"),
          pw.Text("Sessions: ${trend['total_exercise_sessions']}"),
          pw.SizedBox(height: 16),
          pw.Text("Summary: ", style: pw.TextStyle(fontSize: 18)),
          pw.Text("${trend['ai_summary']}"),
          pw.SizedBox(height: 16),
          pw.Text("✨ AI Summary Insights", style: pw.TextStyle(fontSize: 18)),
          pw.Text(aiInsight),
          pw.SizedBox(height: 16),
          pw.Text("🎯 Focus Area", style: pw.TextStyle(fontSize: 18)),
          pw.Text("Avg Glucose Prediction: $formattedGlucose $_selectedUnit"),
          pw.Text("Focus: Maintain steady glucose, prioritize rest."),
        ],
      ),
    );


    await Printing.layoutPdf(
      name:
          'Glycolog_Insights_${DateTime.now().toIso8601String().split('T').first}.pdf',
      onLayout: (format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Personal Insights"),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: "Download PDF",
            onPressed: isLoading ? null : generatePdf,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildTrendCard(insightsData!['trend']),
                const SizedBox(height: 20),
                _buildAIInsight(insightsData!['ai_insight']),
                const SizedBox(height: 20),
                _buildFocusAreas(insightsData!),
              ],
            ),
    );
  }

  Widget _buildTrendCard(Map trend) {
    return FutureBuilder<String>(
      future: formatGlucoseDynamic(trend['avg_glucose_level']?.toDouble()),
      builder: (context, snapshot) {
        final formattedGlucose = snapshot.data ?? '-';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("📊 Weekly Health Trend",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                Text("Glucose: $formattedGlucose $_selectedUnit"),
                Text("Steps: ${trend['avg_steps']}"),
                Text("Sleep: ${trend['avg_sleep_hours']} hrs"),
                Text("Heart Rate: ${trend['avg_heart_rate']} bpm"),
                Text("Sessions: ${trend['total_exercise_sessions']}"),
                const SizedBox(height: 10),
                Text("Summary: ${trend['ai_summary']}"),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAIInsight(String aiInsight) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("🧠 AI Summary Insight",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Text(aiInsight),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusAreas(Map data) {
    final glucoseInfo = data['glucose'] ?? {};
    final avgGlucose = glucoseInfo['average']?.toDouble();

    return FutureBuilder<String>(
      future: formatGlucoseDynamic(avgGlucose),
      builder: (context, snapshot) {
        final formattedGlucose = snapshot.data ?? '-';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("🎯 Next Focus Area",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                Text("Avg Glucose Level: $formattedGlucose $_selectedUnit"),
                const SizedBox(height: 10),
                const Text("Focus: Maintain steady glucose, prioritize rest."),
              ],
            ),
          ),
        );
      },
    );
  }
}
