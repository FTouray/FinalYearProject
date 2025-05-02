import 'dart:convert';
import 'package:glycolog/home/personal_trends_widget.dart';
import 'package:glycolog/questionnaire/data_visualization.dart';
import 'package:glycolog/utils.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:glycolog/services/auth_service.dart';
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
  List<Map<String, dynamic>> predictiveFeedback = [];

  @override
  void initState() {
    super.initState();
    _loadUnitAndFetchInsights();
    fetchPredictiveFeedback();
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
        final summaryData = json.decode(summaryRes.body);
        final trendData = json.decode(trendRes.body);

        setState(() {
          insightsData = {
            ...summaryData,
            "trend": trendData['trend'] ?? {},
          };
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          insightsData = {}; // mark it as loaded, but empty
        });
      }
    } catch (e) {
      print("Error fetching insights: $e");
      setState(() {
        isLoading = false;
        insightsData = {}; // fallback in case of error
      });
    }
  }

  Future<void> fetchPredictiveFeedback() async {
    final token = await AuthService().getAccessToken();
    if (token == null) return;

    final prefs = await SharedPreferences.getInstance();
    final glucoseUnit = prefs.getString('selectedUnit') ?? 'mg/dL';

    final res = await http.get(
      Uri.parse('$apiUrl/predictive-feedback/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Glucose-Unit': glucoseUnit,
      },
    );

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final List<Map<String, dynamic>> allRaw = List<Map<String, dynamic>>.from(
          data['predictive_feedback']['all'] ?? []);
      final now = DateTime.now();
      final filtered = allRaw.where((item) {
        final timestamp = DateTime.tryParse(item['timestamp'] ?? '');
        return timestamp != null && now.difference(timestamp).inDays <= 30;
      }).toList();

      setState(() {
        predictiveFeedback = filtered;
      });
    }
  }

  String determinePriority(String text) {
    text = text.toLowerCase();
    if (text.contains("frequent") ||
        text.contains("consistent") ||
        text.contains("persistent") ||
        text.contains("high glycaemic index") ||
        text.contains("elevated glucose")) {
      return "High";
    } else if (text.contains("may") ||
        text.contains("linked") ||
        text.contains("might") ||
        text.contains("suggest")) {
      return "Medium";
    } else {
      return "Low";
    }
  }


Future<void> generatePdf() async {
    final pdf = pw.Document();
    final trend = insightsData!['trend'];
    final avgGlucose = insightsData?['glucose']?['average']?.toDouble();
    final aiInsight = insightsData?['ai_insight'] ?? "No insights available.";
    final summaryItems =
        List<Map<String, dynamic>>.from(trend['ai_summary_items'] ?? []);
    summaryItems.sort((a, b) => (b['score'] ?? 0).compareTo(a['score'] ?? 0));
    final formattedGlucose = await formatGlucoseDynamic(avgGlucose);

    final List<Map<String, dynamic>> structuredFeedback = predictiveFeedback
        .map((item) => {
              "text": item["text"],
              "priority": determinePriority(item["text"] ?? ""),
            })
        .toList();
    structuredFeedback.sort((a, b) {
      const order = {"High": 0, "Medium": 1, "Low": 2};
      return order[a['priority']]!.compareTo(order[b['priority']]!);
    });

    pw.Widget divider() => pw.Divider(thickness: 0.8, color: PdfColors.grey300);

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Text("Personal Insights Summary",
              style:
                  pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.Text("Generated on: ${DateTime.now().toLocal()}",
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
          pw.SizedBox(height: 20),

          // Health Overview Section
          pw.Text("Health Trend Overview",
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Bullet(text: "Glucose Average: $formattedGlucose $_selectedUnit"),
          pw.Bullet(text: "Steps: ${trend['avg_steps']}"),
          pw.Bullet(
              text:
                  "Heart Rate: ${(trend['avg_heart_rate'] ?? 0).toDouble().toStringAsFixed(2)} bpm"),
          pw.Bullet(
              text: "Exercise Sessions: ${trend['total_exercise_sessions']}"),
          pw.SizedBox(height: 12),
          divider(),

          // AI Summary Items
          pw.SizedBox(height: 10),
          pw.Text("Key AI Recommendations",
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (summaryItems.isNotEmpty)
            ...summaryItems.map((item) => pw.Bullet(
                  text: "[${item['score']}] ${item['text']}",
                ))
          else
            pw.Text("No AI highlights available."),
          pw.SizedBox(height: 12),
          divider(),

          // Full AI Text
          pw.SizedBox(height: 10),
          pw.Text("Full AI Summary",
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(aiInsight, style: pw.TextStyle(fontSize: 13)),
          pw.SizedBox(height: 12),
          divider(),

          pw.SizedBox(height: 10),
          pw.Text("🧠 AI Coach - Predictive Insights",
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (structuredFeedback.isNotEmpty)
            ...structuredFeedback.map((item) => pw.Bullet(
                  text: "(${item['priority']}) ${item['text']}",
                ))
          else
            pw.Text("No predictive insights available."),
          pw.SizedBox(height: 12),
          divider(),

          // Focus Area
          pw.SizedBox(height: 10),
          pw.Text("Focus Area",
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
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
            onPressed:
                isLoading || insightsData?.isEmpty == true ? null : generatePdf,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (insightsData == null || insightsData!.isEmpty)
              ? _buildEmptyState()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildTrendCard(insightsData!['trend']),
                    const SizedBox(height: 20),
                    _buildAIInsight(insightsData!['ai_insight']),
                    PersonalTrendsWidget(),
                    const SizedBox(height: 20),
                    _buildFocusAreas(insightsData!),
                    const SizedBox(height: 20),
                    TextButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text("Export to PDF"),
                      onPressed: generatePdf,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.bar_chart),
                      label: const Text("View Data Visualisation"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const QuestionnaireVisualizationScreen(),
                          ),
                        );
                      },
                    ),

                  ],
                ),
    );
  }
Widget _buildPredictiveSection(List<Map<String, dynamic>> items) {
    return Card(
      color: Colors.teal.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "🧠 AI Coach - Predictive Insights",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ...items.take(5).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text("• ${item['text']}",
                      style: const TextStyle(fontSize: 14)),
                )),
            if (items.length > 5)
              TextButton(
                child: const Text("Show More"),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("All Predictive Insights"),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView(
                          children: items
                              .map((item) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0),
                                    child: Text("• ${item['text']}"),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.insights_outlined, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "No insights available yet.",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              "Start logging your glucose, meals, and activities to generate personalised insights!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildTrendCard(Map trend) {
    return FutureBuilder<String>(
      future: formatGlucoseDynamic(trend['avg_glucose_level']?.toDouble()),
      builder: (context, snapshot) {
        final formattedGlucose = snapshot.data ?? '-';
        final List<dynamic> aiSummaryItems =
            List.from(trend['ai_summary_items'] ?? []);
        aiSummaryItems
            .sort((a, b) => (b['score'] ?? 0).compareTo(a['score'] ?? 0));
        final aiSummaryText = trend['ai_summary'] ?? "No summary available.";

        bool showFullSummary = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "📊 Weekly Health Snapshot",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                            child: _trendTile("🩺 Glucose",
                                "$formattedGlucose $_selectedUnit")),
                        const SizedBox(width: 16),
                        Flexible(
                            child: _trendTile("🚶 Steps",
                                trend['avg_steps']?.toString() ?? "-")),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // _trendTile(
                        //     "🛌 Sleep", "${trend['avg_sleep_hours']} hrs"),
                        _trendTile("❤️ BPM", "${(trend['avg_heart_rate'] ?? 0).toDouble().toStringAsFixed(2)} bpm"),
                        _trendTile("🏋️‍♀️ Sessions",
                            trend['total_exercise_sessions'].toString()),
                      ],
                    ),                    
                    const Divider(height: 24),
                    const Text(
                      "💡 AI Highlights",
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (aiSummaryItems.isEmpty)
                      const Text("No recommendations yet.")
                    else
                      ...aiSummaryItems.take(3).map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(
                              "• ${item['text']}",
                              style: TextStyle(
                                color: item['score'] == 3
                                    ? Colors.red[800]
                                    : item['score'] == 2
                                        ? Colors.orange[800]
                                        : Colors.black87,
                                fontWeight: item['score'] == 3
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          )),
                    const SizedBox(height: 12),
                    if (aiSummaryItems.length > 3 || aiSummaryText.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(
                              () => showFullSummary = !showFullSummary),
                          icon: const Icon(Icons.insights),
                          label: Text(showFullSummary
                              ? "Hide Full Summary"
                              : "View Full Summary"),
                        ),
                      ),
                    if (showFullSummary)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          aiSummaryText,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  Widget _trendTile(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.teal,
          ),
        ),
      ],
    );
  }


  Widget _buildAIInsight(String aiInsight) {
    final lines =
        aiInsight.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final bool isLong = lines.length > 4;
    bool showAll = false;

    return StatefulBuilder(
      builder: (context, setState) {
        final display = showAll ? lines : lines.take(4).toList();
        return Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("🧠 AI Coach Summary",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                ...display.map((line) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child:
                          Text("• $line", style: const TextStyle(fontSize: 14)),
                    )),
                if (isLong)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      child: Text(showAll ? "Show Less" : "Show More"),
                      onPressed: () => setState(() => showAll = !showAll),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
