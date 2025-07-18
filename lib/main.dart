import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:rwa_app/provider/settings_provider.dart';
import 'package:rwa_app/screens/botttom_nav_screen.dart';
import 'package:rwa_app/screens/no_internet_screen.dart';
import 'package:rwa_app/theme/theme.dart';
import 'package:rwa_app/widgets/news/news_detail_screen.dart';
import 'package:rwa_app/screens/podcast_player_screen.dart';
import 'package:shimmer/shimmer.dart';

import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_localizations/flutter_localizations.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.high,
);

RemoteMessage? initialFCMMessage;
final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

Future<void> handlePushNavigation(Map<String, dynamic> data) async {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  final type = data['type']?.toLowerCase();
  final subject = data['subject']?.toLowerCase();

  if (type == 'news' || subject == 'news') {
    final newsSlug = data['slug'] ?? data['id'];
    if (newsSlug == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final url =
        'https://rwa-f1623a22e3ed.herokuapp.com/api/currencies/rwa/news/$newsSlug';
    try {
      final response = await http.get(Uri.parse(url));
      Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode != 200) throw Exception('Failed');
      final news = jsonDecode(response.body)['news'];
      final newsItem = {
        'thumbnail': news['thumbnail'],
        'title': news['title'],
        'subTitle': news['subTitle'],
        'source': news['author'],
        'authorImage': news['authorImage'] ?? '',
        'publishDate': news['publishDate'],
        'updatedAt': news['updatedAt'],
        'slug': news['slug'] ?? '',
        'content': news['content'] ?? '',
        'quote': news['quote'] ?? '',
        'tags': news['tags'] ?? [],
        'bulletPoints': news['bulletPoints'] ?? [],
      };

      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => NewsDetailScreen(news: newsItem)),
      );
    } catch (_) {
      Navigator.of(context, rootNavigator: true).pop();
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text('Error'),
              content: const Text('Failed to load news.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }
  } else if (type == 'podcast' || subject == 'podcast') {
    final url = data['youtubeUrl'];
    if (url == null || url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PodcastPlayerScreen(youtubeUrl: url)),
    );
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final prefs = await SharedPreferences.getInstance();

  final fcmToken = await FirebaseMessaging.instance.getToken();
  print(fcmToken);
  if (fcmToken != null && prefs.getString('fcm_token') != fcmToken) {
    try {
      final response = await http.post(
        Uri.parse('https://rwa-f1623a22e3ed.herokuapp.com/api/users/fcmtoken'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': fcmToken}),
      );
      if (response.statusCode == 200) {
        await prefs.setString('fcm_token', fcmToken);
      }
    } catch (_) {}
  }

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  final initSettings = InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (response) {
      if (response.payload != null) {
        final data = jsonDecode(response.payload!);
        Future.delayed(const Duration(milliseconds: 300), () {
          handlePushNavigation(data);
        });
      }
    },
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    handlePushNavigation(message.data);
  });

  FirebaseMessaging.onMessage.listen((message) async {
    final notification = message.notification;
    final android = message.notification?.android;
    if (notification != null && android != null) {
      await flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  });

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool? _hasInternet;

  @override
  void initState() {
    super.initState();
    _checkInitialInternet();
    _monitorInternet();
  }

  Future<void> _checkInitialInternet() async {
    final result = await Connectivity().checkConnectivity();
    if (result != ConnectivityResult.none) {
      try {
        final lookup = await InternetAddress.lookup('example.com');
        setState(() {
          _hasInternet = lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
        });
      } on SocketException {
        setState(() => _hasInternet = false);
      }
    } else {
      setState(() => _hasInternet = false);
    }
  }

  void _monitorInternet() {
    Connectivity().onConnectivityChanged.listen((result) async {
      bool hasInternet = false;
      if (result != ConnectivityResult.none) {
        try {
          final lookup = await InternetAddress.lookup('example.com');
          hasInternet = lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
        } on SocketException {
          hasInternet = false;
        }
      }
      setState(() {
        _hasInternet = hasInternet;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        quill.FlutterQuillLocalizations.delegate, // ✅ Add this
      ],
      supportedLocales: const [
        Locale('en'),
        // Add other supported locales here if needed
      ],
      navigatorKey: navigatorKey,
      title: 'RWA PROS',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home:
          _hasInternet == null
              ? const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF0087E0)),
                ),
              )
              : _hasInternet!
              ? const BottomNavScreen()
              : const NoInternetScreen(),
    );
  }
}
