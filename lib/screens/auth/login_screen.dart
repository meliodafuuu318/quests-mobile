import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../app_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter username and password');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final auth = context.read<AuthProvider>();
      final ok = await auth.login(username, password);

      if (!mounted) return;

      if (ok) {
        // Navigate directly — don't rely on Consumer rebuilding
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AppShell()),
          (route) => false,
        );
      } else {
        setState(() {
          _loading = false;
          _error = auth.error ?? 'Login failed. Check your credentials.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Connection error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.2, -0.6),
            radius: 1.1,
            colors: [AppTheme.violetDim, AppTheme.bg, AppTheme.bg],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                // Brand
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.gold.withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.shield_outlined, color: AppTheme.gold, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text('QUESTS', style: AppTheme.mono(color: AppTheme.textPrimary, size: 22)),
                ]),
                const SizedBox(height: 60),
                Text('WELCOME\nBACK', style: AppTheme.mono(color: AppTheme.textPrimary, size: 36)),
                const SizedBox(height: 8),
                Text('Your quests await, adventurer.', style: AppTheme.label(color: AppTheme.textSecondary, size: 15)),
                const SizedBox(height: 44),

                // Error box
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.roseDim,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.rose.withOpacity(0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppTheme.rose, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: AppTheme.label(color: AppTheme.rose, size: 13))),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline, size: 18),
                  ),
                  style: AppTheme.label(color: AppTheme.textPrimary),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) { if (_error != null) setState(() => _error = null); },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                        color: AppTheme.textMuted,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  style: AppTheme.label(color: AppTheme.textPrimary),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _loading ? null : _login(),
                  onChanged: (_) { if (_error != null) setState(() => _error = null); },
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: GlowButton(
                    label: 'ENTER THE REALM',
                    onPressed: _loading ? null : _login,
                    isLoading: _loading,
                    icon: Icons.arrow_forward,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('New adventurer? ', style: AppTheme.label(color: AppTheme.textSecondary, size: 14)),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: Text(
                        'Create Account',
                        style: AppTheme.label(color: AppTheme.gold, size: 14, weight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}