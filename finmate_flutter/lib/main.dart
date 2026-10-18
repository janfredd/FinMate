import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme.dart';
import 'presentation/screens/shell.dart';

@pragma('vm:entry-point')
Future<void> _bg(RemoteMessage m) async {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(); // needs google-services.json
    FirebaseMessaging.onBackgroundMessage(_bg);
  } catch (_) {
    // Run without FCM in dev/emulator.
  }
  runApp(const ProviderScope(child: FinMateApp()));
}

class FinMateApp extends ConsumerStatefulWidget {
  const FinMateApp({super.key});
  @override
  ConsumerState<FinMateApp> createState() => _AppState();
}

class _AppState extends ConsumerState<FinMateApp> {
  @override
  void initState() {
    super.initState();
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${n.title ?? ''}: ${n.body ?? ''}')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'FinMate', theme: finMateTheme,
        home: const SplashLoader(),
        debugShowCheckedModeBanner: false);
  }
}
