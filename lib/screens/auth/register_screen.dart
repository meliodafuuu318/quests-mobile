import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    for (final c in [_usernameCtrl, _emailCtrl, _passwordCtrl, _firstNameCtrl, _lastNameCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      username: _usernameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
    );
    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Account created! Please log in.'),
          backgroundColor: AppTheme.cyan,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(auth.error ?? 'Registration failed'),
          backgroundColor: AppTheme.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    }
  }

  Widget _field(TextEditingController ctrl, String label, {
    IconData? icon, bool obscure = false,
    TextInputAction action = TextInputAction.next,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl, obscureText: obscure,
        textInputAction: action, keyboardType: keyboardType,
        validator: validator ?? (v) => v == null || v.isEmpty ? 'Required' : null,
        decoration: InputDecoration(labelText: label, prefixIcon: icon != null ? Icon(icon, size: 18) : null),
        style: AppTheme.label(color: AppTheme.textPrimary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CREATE ACCOUNT'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text('JOIN THE\nADVENTURE', style: AppTheme.mono(color: AppTheme.textPrimary, size: 30)),
              const SizedBox(height: 6),
              Text('Complete quests. Earn rewards. Rise the ranks.', style: AppTheme.label(color: AppTheme.textSecondary, size: 13)),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(child: _field(_firstNameCtrl, 'First Name', icon: Icons.badge_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_lastNameCtrl, 'Last Name')),
                ],
              ),
              _field(_usernameCtrl, 'Username', icon: Icons.alternate_email,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : v.length < 3 ? 'Min 3 chars' : null),
              _field(_emailCtrl, 'Email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : !v.contains('@') ? 'Invalid email' : null),
              TextFormField(
                controller: _passwordCtrl, obscureText: _obscure,
                textInputAction: TextInputAction.done,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : v.length < 8 ? 'Min 8 chars' : null,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppTheme.textMuted),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                style: AppTheme.label(color: AppTheme.textPrimary),
                onFieldSubmitted: (_) => _register(),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cyanDim,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cyan.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.cyan, size: 16),
                    const SizedBox(width: 10),
                    Expanded(child: Text('You\'ll start with 100 credits. Joining quests costs 25 credits.', style: AppTheme.label(color: AppTheme.textSecondary, size: 12))),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Consumer<AuthProvider>(
                builder: (_, auth, __) => SizedBox(
                  width: double.infinity,
                  child: GlowButton(label: 'BEGIN YOUR JOURNEY', onPressed: _register, isLoading: auth.isLoading, icon: Icons.rocket_launch_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}