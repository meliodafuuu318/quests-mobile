import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuestApp());
}

class QuestApp extends StatelessWidget {
  const QuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
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
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Small delay so the widget tree is fully built first
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    try {
      await context.read<AuthProvider>().init();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) {
        final auth = context.read<AuthProvider>();
        return auth.isLoggedIn ? const AppShell() : const LoginScreen();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, color: AppTheme.gold, size: 56),
            SizedBox(height: 20),
            Text(
              'QUESTS',
              style: TextStyle(
                color: AppTheme.gold,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                letterSpacing: 4,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Loading...',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            SizedBox(height: 32),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold),
            ),
          ],
        ),
      ),
    );
  }
}