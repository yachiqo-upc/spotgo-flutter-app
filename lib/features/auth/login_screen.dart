import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/spotgo_logo.dart';
import '../../data/mock/mock_auth_repository.dart';

/// Sign in for provisioned Parking Admin accounts. There is no public sign-up.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.showDemoHint = true});

  final bool showDemoHint;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await AppScope.of(
      context,
    ).auth.signIn(_emailController.text, _passwordController.text);
  }

  void _showForgotPassword() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot password?'),
        content: const Text(
          'Parking Admin accounts are provisioned by SuperAdmin. '
          'Ask your SuperAdmin to reset your access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageContainer(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: ListenableBuilder(
              listenable: auth,
              builder: (context, _) => Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: SpotGoLogo(fontSize: 22),
                    ),
                    const SizedBox(height: 18),
                    Text('Parking Admin', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    Text(
                      'Monitor occupancy, alerts, zones and guest sessions.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 44),
                    Text('Sign in', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 10),
                    Text(
                      'Use the Administrator account enabled by SuperAdmin.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      key: const Key('login-email'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'admin@example.com',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Enter your email';
                        if (!_emailPattern.hasMatch(text)) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('login-password'),
                      controller: _passwordController,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter your password';
                        }
                        if (value.length < 8) {
                          return 'Password must have at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPassword,
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    if (auth.error != null) ...[
                      Container(
                        key: const Key('login-error'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dangerMuted,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          auth.error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton(
                      key: const Key('login-submit'),
                      onPressed: auth.loading ? null : _submit,
                      child: auth.loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            )
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: 18),
                    const NoticeCard(
                      icon: Icons.admin_panel_settings_outlined,
                      message:
                          'Administrator accounts are enabled by SpotGo '
                          'SuperAdmin. Public registration is not available '
                          'in this app.',
                    ),
                    if (widget.showDemoHint) ...[
                      const SizedBox(height: 12),
                      const NoticeCard(
                        title: 'Demo data mode',
                        message:
                            'The SpotGo backend is not connected. Sign in with '
                            '${MockAuthRepository.demoEmail} / '
                            '${MockAuthRepository.demoPassword} to explore '
                            'local sample data.',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
