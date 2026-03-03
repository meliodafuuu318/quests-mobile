import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'services/pusher_service.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/app_shell.dart';
import 'screens/feed/post_detail_screen.dart';
import 'widgets/common_widgets.dart';
import 'widgets/notification_panel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Wire bell → panel (avoids circular import between common_widgets ↔ notification_panel)
  NotificationBellRouter.register((ctx) => showNotificationPanel(ctx));

  // Wire panel → PostDetailScreen (avoids circular import between notification_panel ↔ post_detail_screen)
  NotificationRouter.register((postId) => PostDetailScreen(postId: postId));

  runApp(const QuestApp());
}

class QuestApp extends StatelessWidget {
  const QuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Expose PusherService singleton so NotificationBell auto-rebuilds.
        ChangeNotifierProvider.value(value: PusherService.instance),
      ],
      child: MaterialApp(
        title: 'Quests',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const _Splash(),
      ),
    );
  }
}

class _Splash extends StatefulWidget {
  const _Splash();
  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> {
  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    try { await context.read<AuthProvider>().init(); } catch (_) {}
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => auth.isLoggedIn ? const AppShell() : const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shield_outlined, color: AppTheme.gold, size: 56),
          SizedBox(height: 20),
          Text('QUESTS', style: TextStyle(
            color: AppTheme.gold, fontSize: 24, fontWeight: FontWeight.w900,
            fontFamily: 'monospace', letterSpacing: 4,
          )),
          SizedBox(height: 8),
          Text('Loading...', style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontFamily: 'monospace')),
          SizedBox(height: 32),
          SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold)),
        ]),
      ),
    );
  }
}