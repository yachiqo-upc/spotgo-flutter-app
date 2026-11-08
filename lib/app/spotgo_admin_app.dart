import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/spotgo_logo.dart';
import '../data/mock/mock_auth_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../features/auth/login_screen.dart';
import '../state/auth_controller.dart';
import 'app_scope.dart';

class SpotGoAdminApp extends StatefulWidget {
  const SpotGoAdminApp({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<SpotGoAdminApp> createState() => _SpotGoAdminAppState();
}

class _SpotGoAdminAppState extends State<SpotGoAdminApp> {
  late final AuthController _auth = AuthController(
    widget.authRepository ?? MockAuthRepository(),
  );

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      auth: _auth,
      child: MaterialApp(
        title: 'SpotGo Parking Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: ListenableBuilder(
          listenable: _auth,
          builder: (context, _) => _auth.isAuthenticated
              ? const Scaffold(body: Center(child: SpotGoLogo(fontSize: 36)))
              : const LoginScreen(),
        ),
      ),
    );
  }
}
