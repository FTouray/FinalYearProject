// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_background_service_android/flutter_background_service_android.dart';
// import 'package:awesome_notifications/awesome_notifications.dart';
// import 'package:Glycolog/services/health_connect_service.dart';
// import 'package:Glycolog/services/auth_service.dart';
// import 'dart:async';

// @pragma('vm:entry-point')
// Future<void> backgroundServiceEntryPoint(ServiceInstance service) async {
//   // Run only on Android foreground mode
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
//           id: 1,
//           channelKey: 'daily_health_summary',
//           title: '✅ Health Data Synced',
//           body: 'Your health data has been successfully synced!',
//           notificationLayout: NotificationLayout.Default,
//         ),
//       );
//     }
//   }

//   // Optionally stop the service if it’s one-time
//   service.stopSelf();
// }

// Future<void> initializeService() async {
//   final service = FlutterBackgroundService();

//   await service.configure(
//     androidConfiguration: AndroidConfiguration(
//       onStart: backgroundServiceEntryPoint,
//       isForegroundMode: true,
//       autoStart: false,
//       notificationChannelId: 'daily_health_summary',
//       initialNotificationTitle: 'Glycolog Running in Background',
//       initialNotificationContent: 'Monitoring your health sync.',
//     ),
//     iosConfiguration: IosConfiguration(),
//   );
// }
