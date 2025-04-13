import 'dart:convert';
import 'package:Glycolog/home/predictive_feedback_widget.dart';
import 'package:Glycolog/learning/gamification_dashboard_widget.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'base_screen.dart';
import 'package:Glycolog/services/auth_service.dart';

class HomePage extends StatefulWidget {
  final String? firstName;
  const HomePage({super.key, this.firstName});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final String? apiUrl = dotenv.env['API_URL'];
  String? _displayName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  
Future<void> _setup() async {
    await _checkAuthentication(); // Ensure token is valid first
    await _initialize(); // Then proceed
    setState(() {}); // Trigger UI rebuild
  }

  Future<void> _initialize() async {
    _handleFirstLaunch();
    setState(() {}); // Rebuild with updated name
  }

  void _loadDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    final firstNameArg = ModalRoute.of(context)?.settings.arguments as String?;
    final storedName = prefs.getString('first_name');

    setState(() {
      _displayName = firstNameArg ?? storedName ?? 'User';
      if (firstNameArg != null && firstNameArg != storedName) {
        prefs.setString(
            'first_name', firstNameArg); // update stored name if needed
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDisplayName();
  }


  Future<void> _checkAuthentication() async {
    AuthService authService = AuthService();
    String? token = await authService.getAccessToken();
    if (token == null)
      await authService.logout(context);
    else
      await authService.refreshAccessToken(context);
  }

  Future<void> _handleFirstLaunch() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('wasAppOpened') ?? false)) {
      await prefs.setBool('wasAppOpened', true);
      _showFeelingPopup(context);
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    final routes = ['/home', '/forum', '/settings'];
    if (ModalRoute.of(context)?.settings.name != routes[index]) {
      Navigator.pushNamed(context, routes[index]);
    }
  }

  void _showFeelingPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        title: const Text(
          "Not Feeling Well?",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Let's check in and figure out what's going on.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.monitor_heart),
              label: const Text("Start Check-In"),
              onPressed: () {
                Navigator.pop(context);
                _startQuestionnaire("bad");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Maybe Later",
                style: TextStyle(fontSize: 16, color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _navigateToInsights(String feeling) {
    Navigator.pop(context);
    Navigator.pushNamed(context, '/insights', arguments: {"feeling": feeling});
  }

  Future<void> _startQuestionnaire(String feeling) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null) throw Exception("User is not authenticated.");
      final res = await http.post(
        Uri.parse('$apiUrl/questionnaire/start/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: json.encode({'feeling': feeling}),
      );
      if (res.statusCode == 201) Navigator.pushNamed(context, '/symptom-step');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start questionnaire.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffoldScreen(
      selectedIndex: _selectedIndex,
      onItemTapped: (index) {
        setState(() => _selectedIndex = index);
        final routes = ['/home', '/forum', '/settings'];
        if (index >= 0 && index < routes.length) {
          Navigator.pushNamed(context, routes[index]);
        }
      },
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _getGreetingMessage(),
                key: ValueKey(_displayName),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ),
            PredictiveFeedbackWidget(),
            const SizedBox(height: 16),
            const Text(
              "Here’s what you can explore today:",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            GamificationDashboardCard(),
            const SizedBox(height: 24),
            _buildFeatureItem(
              "💬 Not Feeling Well",
              "Let us know how you’re feeling.",
              () => _showFeelingPopup(context),
            ),
            _buildFeatureItem(
              "📊 Log Your Glucose",
              "See how your levels are trending.",
              () => Navigator.pushNamed(context, '/glucose-log'),
            ),
            _buildFeatureItem(
              "🥗 Track Your Meals",
              "See how your meals affect your glucose.",
              () => Navigator.pushNamed(context, '/glycaemic-response-main'),
            ),
            _buildFeatureItem(
              "🏃‍♂️ Fitness Summary",
              "See how far you’ve moved this week.",
              () => Navigator.pushNamed(context, '/virtual-health-dashboard'),
            ),
            _buildFeatureItem(
              "💊 Medications",
              "Review or log your current meds.",
              () => Navigator.pushNamed(context, '/medications'),
            ),
            _buildFeatureItem(
              "📈 Personal Insights",
              "Reflections from your data.",
              () => Navigator.pushNamed(context, '/insights'),
            ),
            _buildFeatureItem(
              "🎮 Learning Adventure",
              "Take on interactive diabetes challenges!",
              () => Navigator.pushNamed(context, '/gamification'),
            ),
          ],
        ),
      ),
    );
  }

String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    String greeting;
    String emoji;

    if (hour < 12) {
      greeting = "Good morning";
      emoji = "☀️";
    } else if (hour < 17) {
      greeting = "Good afternoon";
      emoji = "🌤️";
    } else {
      greeting = "Good evening";
      emoji = "🌙";
    }

    return "$greeting, $_displayName! $emoji";
  }


  Widget _buildFeatureItem(String title, String subtitle, VoidCallback onTap,
    {IconData icon = Icons.chevron_right, Color? color}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: Colors.white),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white70),
        ],
      ),
    ),
  );
}

}
