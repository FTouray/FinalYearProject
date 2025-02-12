import 'package:flutter/material.dart';
import 'package:Glycolog/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GRTAnalysisScreen extends StatefulWidget {
  @override
  _GRTAnalysisScreenState createState() => _GRTAnalysisScreenState();
}

class _GRTAnalysisScreenState extends State<GRTAnalysisScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> insights = [];

  @override
  void initState() {
    super.initState();
    _fetchInsights();
  }

  Future<void> _fetchInsights() async {
    final apiUrl = dotenv.env['API_URL'];
    String? token = await AuthService().getAccessToken();
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/glycaemic-response-analysis'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          insights = data['insights'];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load insights';
          isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        errorMessage = 'An error occurred: $error';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Glycaemic Response Analysis"),
        backgroundColor: Colors.blue[800],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ...insights.map((insight) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Meal ID: ${insight['meal_id']}",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 10),
                            Text("Timestamp: ${insight['meal_timestamp']}"),
                            SizedBox(height: 10),
                            Text("Average Glucose Level: ${insight['avg_glucose_level']}"),
                            SizedBox(height: 10),
                            Text("Total Glycaemic Index: ${insight['total_glycaemic_index']}"),
                            SizedBox(height: 10),
                            Text("Total Carbs: ${insight['total_carbs']}"),
                            SizedBox(height: 10),
                            Text("Food Items:"),
                            ...insight['food_items'].map<Widget>((item) {
                              return Text("- ${item['name']}: GI ${item['glycaemic_index']}, Carbs ${item['carbs']}g");
                            }).toList(),
                            SizedBox(height: 10),
                            Text(
                              "Recommendation: ${insight['recommendation']}",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }
}