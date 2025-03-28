import 'package:Glycolog/services/health_sync_service.dart';
import 'glycaemicResponseTracker/gRT_history_detail_screen.dart';
import 'package:Glycolog/glycaemicResponseTracker/gRT_meal_log_history_screen.dart';
import 'package:Glycolog/glycaemicResponseTracker/gRT_meal_log_screen.dart';
import 'package:Glycolog/medicationTracker/add_medication_screen.dart';
import 'package:Glycolog/medicationTracker/medication_reminder_screen.dart';
import 'package:Glycolog/medicationTracker/edit_medication_screen.dart';
import 'package:Glycolog/medicationTracker/medications_screen.dart';
import 'package:Glycolog/questionnaire/data_visualization.dart';
import 'package:Glycolog/questionnaire/exercise_step.dart';
import 'package:Glycolog/questionnaire/meal_step.dart';
import 'package:Glycolog/questionnaire/symptom_step.dart';
import 'package:Glycolog/services/auth_service.dart';
import 'package:Glycolog/virtualHealthCoach/chatbot_screen.dart';
import 'package:Glycolog/virtualHealthCoach/virtual_health_dashboard.dart';
import 'package:flutter/material.dart';
import 'glucoseLog/gL_add_level_screen.dart';
import 'glucoseLog/gL_history_screen.dart';
import 'glucoseLog/gL_detail_screen.dart';
import 'glucoseLog/gL_main_screen.dart';
import 'home/insights_screen.dart';
import 'home/onboarding_screen.dart';
import 'loginRegister/login_screen.dart';
import 'home/homepage_screen.dart';
import 'loginRegister/register_screen.dart';
import 'home/settings_screen.dart';
import 'glycaemicResponseTracker/gRT_main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';  
import 'questionnaire/glucose_step.dart';
import 'questionnaire/review.dart';
//import 'package:awesome_notifications/awesome_notifications.dart';
//import 'package:flutter_background_service/flutter_background_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
//final AwesomeNotifications awesomeNotifications = AwesomeNotifications();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/.env");

 // await _initNotifications();
 // await _initBackgroundService();

  final darkMode = await _loadDarkModePreference();
  final token = await _loadToken();


  runApp(MyApp(darkModeEnabled: darkMode, token: token));

  if (token != null) {
    await _syncHealthData(token);
  }
}

// Future<void> _initNotifications() async {
//   await awesomeNotifications.initialize(
//     null,
//     [
//       NotificationChannel(
//         channelKey: 'daily_health_summary',
//         channelName: 'Daily Health Summary',
//         channelDescription: 'Notifications for daily health sync results',
//         defaultColor: const Color(0xFF9D50DD),
//         importance: NotificationImportance.High,
//         channelShowBadge: true,
//       )
//     ],
//     debug: true,
//   );
// }

// Future<void> _initBackgroundService() async {
//   final service = FlutterBackgroundService();

//   await service.configure(
//     androidConfiguration: AndroidConfiguration(
//       onStart: _onBackgroundTask,
//       isForegroundMode: true,
//       autoStart: true,
//       initialNotificationTitle: 'Glycolog Running',
//       initialNotificationContent: 'Background sync active.',
//       notificationChannelId: 'daily_health_summary',
//     ),
//     iosConfiguration: IosConfiguration(),
//   );

//   await service.startService();
// }

// @pragma('vm:entry-point')
// Future<void> _onBackgroundTask(ServiceInstance service) async {
//   if (service is AndroidServiceInstance) {
//     service.on('stopService').listen((event) {
//       service.stopSelf();
//     });
//   }

//   final token = await AuthService().getAccessToken();
//   if (token != null) {
//     final healthService = HealthConnectService();
//     final synced = await healthService.sendToBackend(token);

//     if (synced) {
//       await AwesomeNotifications().createNotification(
//         content: NotificationContent(
//           id: 2,
//           channelKey: 'daily_health_summary',
//           title: '✅ Background Health Sync',
//           body: 'Health data was synced in the background.',
//           notificationLayout: NotificationLayout.Default,
//         ),
//       );
//     }
//   }

//   service.stopSelf();
// }

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
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  String? _token;
  AuthService authService = AuthService();

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.darkModeEnabled;
    _token = widget.token;
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

  // Function to refresh the token
  Future<void> _refreshToken(BuildContext context) async {
    final response = await http.post(
      Uri.parse('$baseUrl/token/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'refresh': _token}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _token = data['access'];
      await _saveToken(_token!);
    } else {
      print('Failed to refresh token: ${response.reasonPhrase}');
      await authService.logout(context);
    }
  }

  // Save the token in SharedPreferences
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
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
        '/home': (context) {
          // Extract arguments (first name) passed during navigation
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is String) {
            return HomePage(firstName: args); // Pass first name to HomePage
          } else {
            return HomePage(
                firstName: 'User'); // Default name if argument is not found
          }
        },
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
