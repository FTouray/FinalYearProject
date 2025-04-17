import 'package:glycolog/forum/forum_create_thread_screen.dart';
import 'package:glycolog/forum/forum_home_screen.dart';
import 'package:glycolog/forum/forum_thread_screen.dart';
import 'package:glycolog/learning/achievement_screen.dart';
import 'package:glycolog/learning/animated_quiz.dart';
import 'package:glycolog/learning/gamification_hub_screen.dart';
import 'package:glycolog/learning/quiz_attempt_history.dart';
import 'package:glycolog/learning/quiz_attempt_review.dart';
import 'package:glycolog/learning/quiz_result.dart';
import 'package:glycolog/services/health_sync_service.dart';
import 'glycaemicResponseTracker/glycaemic_history_detail_screen.dart';
import 'package:glycolog/glycaemicResponseTracker/glycaemic_meal_log_history_screen.dart';
import 'package:glycolog/glycaemicResponseTracker/glycaemic_meal_log_screen.dart';
import 'package:glycolog/medicationTracker/add_medication_screen.dart';
import 'package:glycolog/medicationTracker/medication_reminder_screen.dart';
import 'package:glycolog/medicationTracker/edit_medication_screen.dart';
import 'package:glycolog/medicationTracker/medications_screen.dart';
import 'package:glycolog/questionnaire/data_visualization.dart';
import 'package:glycolog/questionnaire/exercise_step.dart';
import 'package:glycolog/questionnaire/meal_step.dart';
import 'package:glycolog/questionnaire/symptom_step.dart';
import 'package:glycolog/services/auth_service.dart';
import 'package:glycolog/virtualHealthCoach/chatbot_screen.dart';
import 'package:glycolog/virtualHealthCoach/virtual_health_dashboard.dart';
import 'package:flutter/material.dart';
import 'glucoseLog/glucose_add_level_screen.dart';
import 'glucoseLog/glucose_history_screen.dart';
import 'glucoseLog/glucose_detail_screen.dart';
import 'glucoseLog/glucose_main_screen.dart';
import 'home/insights_screen.dart';
import 'home/onboarding_screen.dart';
import 'loginRegister/login_screen.dart';
import 'home/homepage_screen.dart';
import 'loginRegister/register_screen.dart';
import 'home/settings_screen.dart';
import 'glycaemicResponseTracker/glycaemic_main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';  
import 'questionnaire/glucose_step.dart';
import 'questionnaire/review.dart';
import 'package:timezone/data/latest.dart' as tz;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/.env");

  tz.initializeTimeZones();

  final darkMode = await _loadDarkModePreference();
  final token = await _loadToken();

  runApp(MyApp(darkModeEnabled: darkMode, token: token));

  if (token != null) {
    await _syncHealthData(token);
  }
}


Future<void> _syncHealthData(String token) async {
  final healthService = HealthSyncService();

  try {
    final hasPermission = await healthService.requestPermissions();

    if (!hasPermission) {
      print("Health permissions not granted, skipping sync.");
      return;
    }

    final success = await healthService.syncToBackend();

    if (success) {
      print("Health data synced on app startup.");
    } else {
      print("Failed to sync health data on startup.");
    }
  } catch (e) {
    print("Exception during health data sync: $e");
  }
}


// Function to load dark mode preference
Future<bool> _loadDarkModePreference() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('darkModeEnabled') ?? false;
}

// Function to load token from SharedPreferences
Future<String?> _loadToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('access_token');
}
class MyApp extends StatefulWidget {
  final bool darkModeEnabled;
  final String? token;

  const MyApp({super.key, required this.darkModeEnabled, this.token});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  String? _token;
  AuthService authService = AuthService();
  String? _firstName;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.darkModeEnabled;
    _token = widget.token;
     _loadFirstName().then((name) {
      setState(() {
        _firstName = name ?? 'User';
      });
    });
  }

  // Toggle dark mode
  void _toggleDarkMode(bool isEnabled) {
    setState(() {
      _isDarkMode = isEnabled;
    });
    _saveDarkModePreference(isEnabled);
  }

  // Save dark mode preference
  Future<void> _saveDarkModePreference(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkModeEnabled', isEnabled);
  }

  final String baseUrl = dotenv.env['API_URL']!;


  Future<String?> _loadFirstName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('first_name');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glycolog App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: _isDarkMode
            ? Brightness.dark
            : Brightness.light, // Apply dark mode dynamically
      ),
      initialRoute: _token != null
          ? '/home'
          : '/login', // Navigate based on token presence
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => HomePage(firstName: _firstName ?? 'User'),
        '/onboarding': (context) => OnboardingScreen(),
        '/register': (context) => const RegisterScreen(),
        '/glucose-log': (context) => const GlucoseLogScreen(),
        '/settings': (context) => SettingsScreen(
              onToggleDarkMode:
                  _toggleDarkMode, // Pass the toggle dark mode function to SettingsScreen
            ),
        '/add-log': (context) => const AddGlucoseLevelScreen(),
        '/log-history': (context) => const GlucoseLogHistoryScreen(),
        '/log-details': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return LogDetailsScreen(
              logDetails: args ?? {}); // Pass log details or an empty map
        },
        '/glycaemic-response-main': (context) => GRTMainScreen(),
        '/log-meal': (context) => MealSelectionScreen(),
        '/meal-log-history': (context) => MealLogHistoryScreen(),
        '/meal-log-details': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return MealDetailScreen(meal: args ?? {});
        },
        '/symptom-step': (context) => SymptomStepScreen(),
        '/glucose-step': (context) => GlucoseStepScreen(),
        '/meal-step': (context) => MealStepScreen(),
        '/exercise-step': (context) => ExerciseStepScreen(),
        '/review': (context) => const ReviewScreen(),
        '/data-visualization': (context) => const QuestionnaireVisualizationScreen(),
        '/insights': (context) => const InsightsScreen(),
        '/virtual-health-dashboard': (context) => const VirtualHealthDashboard(),
        '/chatbot': (context) => const ChatbotScreen(),
        '/add-medication': (context) => const AddMedicationScreen(),
        '/medications': (context) => const MedicationsScreen(),
        '/forum': (context) => const ForumHomeScreen(),
        '/forum/create-thread': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return ForumCreateThreadScreen(categoryId: args?['categoryId']);
        },
        '/gamification': (context) => GamificationGameHub(),
        '/gamification/module': (context) {
          final level = ModalRoute.of(context)!.settings.arguments as int;
          return AnimatedQuizPage(level: level);
        },
        '/gamification/result': (context) {
          final result = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return QuizResultPage(
              result: result);
        },
        '/gamification/stats': (context) => AchievementsAndLeaderboard(),
        '/gamification/attempts': (context) => QuizAttemptHistoryPage(),
        '/gamification/attempt-review': (context) {
          final review =
              ModalRoute.of(context)!.settings.arguments as List<dynamic>;
          return QuizAttemptReviewPage(review: review);
        }
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/edit-medication':
            if (settings.arguments is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (context) => EditMedicationScreen(
                  medication: settings.arguments as Map<String, dynamic>,
                ),
              );
            }
            return _errorRoute(); // Handle missing/incorrect arguments safely

          case '/medication-reminder':
            if (settings.arguments is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (context) => MedicationReminderScreen(
                  medication: settings.arguments as Map<String, dynamic>,
                ),
              );
            }
            return _errorRoute(); // Handle incorrect argument passing

          case '/forum/thread':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null &&
                args.containsKey('threadId') &&
                args.containsKey('username')) {
              return MaterialPageRoute(
                builder: (_) => ForumThreadScreen(
                  threadId: args['threadId'].toString(),
                  username: args['username'],
                ),
              );
            }
            return _errorRoute();
            
          default:
            return null; // If the route is not found, let Flutter handle it
        }
      },      
    );
  }

  // Function to return an error page for invalid arguments
  Route<dynamic> _errorRoute() {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: const Center(child: Text("Invalid or missing arguments!")),
      ),
    );
  }
}
