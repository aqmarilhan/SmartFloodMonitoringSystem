import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'login_page.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_page.dart';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';


const String databaseUrl =
    "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app";

const String backgroundChannelId = "flood_background_service";
const int backgroundNotificationId = 888;

final FlutterLocalNotificationsPlugin backgroundNotifications =
    FlutterLocalNotificationsPlugin();

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings("@mipmap/ic_launcher");

  const InitializationSettings settings = InitializationSettings(
    android: androidSettings,
  );

  await backgroundNotifications.initialize(settings);

  await backgroundNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    backgroundChannelId,
    "Flood Background Service",
    description: "Keeps flood monitoring active in background",
    importance: Importance.low,
  );

  await backgroundNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onBackgroundServiceStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: backgroundChannelId,
      initialNotificationTitle: "Smart Flood Monitoring",
      initialNotificationContent: "Background monitoring is active",
      foregroundServiceNotificationId: backgroundNotificationId,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onBackgroundServiceStart,
    ),
  );

  await service.startService();
}

@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await Firebase.initializeApp();

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings("@mipmap/ic_launcher");

  const InitializationSettings settings = InitializationSettings(
    android: androidSettings,
  );

  await backgroundNotifications.initialize(settings);

  final database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: databaseUrl,
  );

  final floodRef = database.ref("FloodMonitoring");

  String previousStatus = "";

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "Smart Flood Monitoring",
      content: "Monitoring flood status in background",
    );
  }

  floodRef.onValue.listen((event) async {
    final data = event.snapshot.value;

    if (data == null || data is! Map) return;

    final floodData = Map<dynamic, dynamic>.from(data);
    final currentStatus =
        floodData["flood_status"]?.toString() ?? "--";

    if (currentStatus == previousStatus) return;

    previousStatus = currentStatus;

    if (currentStatus == "WARNING") {
      await showBackgroundNotification(
        "⚠️ Flood Warning",
        "Water level is increasing. Stay alert.",
      );
    } else if (currentStatus == "DANGEROUS") {
      await showBackgroundNotification(
        "🚨 Flood Alert",
        "Dangerous flood level detected! Move vehicle immediately.",
      );
    }
  });

  service.on("stopService").listen((event) {
    service.stopSelf();
  });
}

Future<void> showBackgroundNotification(
  String title,
  String body,
) async {
  const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
    "flood_alerts",
    "Flood Alerts",
    channelDescription: "Flood monitoring alert notifications",
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails notificationDetails =
      NotificationDetails(android: androidDetails);

  await backgroundNotifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    notificationDetails,
  );
}

  Future<void> createAdminUser() async {
  final database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app",
  );

  await database.ref("Users/OrUyGIlCvHgbniS5S65UHMJDmZl1").set({
    "username": "admin",
    "email": "admin@gmail.com",
    "role": "Admin",
    "createdAt": DateTime.now().toString(),
  });

  debugPrint("Admin user created successfully.");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // await createAdminUser(); // TEMPORARY: run once only

  await initializeBackgroundService();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,

          theme: ThemeData(
            scaffoldBackgroundColor: Colors.lightBlue.shade50,

            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.lightBlue,
              foregroundColor: Colors.white,
              centerTitle: true,
            ),

            cardTheme: const CardThemeData(
              elevation: 4,
            ),
          ),

          darkTheme: ThemeData.dark(),

          themeMode: themeProvider.themeMode,

          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const DashboardPage();
        }

        return const LoginPage();
      },
    );
  }
}

