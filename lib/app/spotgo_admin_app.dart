import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/mock/mock_auth_repository.dart';
import '../data/mock/mock_billing_repository.dart';
import '../data/mock/mock_parking_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/billing_repository.dart';
import '../data/repositories/parking_repository.dart';
import '../features/auth/login_screen.dart';
import '../features/shell/admin_shell.dart';
import '../state/auth_controller.dart';
import '../state/billing_controller.dart';
import 'app_scope.dart';

class SpotGoAdminApp extends StatefulWidget {
  const SpotGoAdminApp({
    super.key,
    this.authRepository,
    this.parkingRepository,
    this.billingRepository,
    this.liveRefreshInterval = const Duration(seconds: 5),
  });

  final AuthRepository? authRepository;
  final ParkingRepository? parkingRepository;
  final BillingRepository? billingRepository;

  /// Polling period for live occupancy (US05 requires updates within 5 s).
  /// Null disables polling (used by tests).
  final Duration? liveRefreshInterval;

  @override
  State<SpotGoAdminApp> createState() => _SpotGoAdminAppState();
}

class _SpotGoAdminAppState extends State<SpotGoAdminApp> {
  late final AuthController _auth = AuthController(
    widget.authRepository ?? MockAuthRepository(),
  );
  late final ParkingRepository _parkingRepository =
      widget.parkingRepository ?? MockParkingRepository();
  late final BillingController _billing = BillingController(
    repository: widget.billingRepository ?? MockBillingRepository(),
  );

  @override
  void dispose() {
    _auth.dispose();
    _billing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      auth: _auth,
      parkingRepository: _parkingRepository,
      billing: _billing,
      child: MaterialApp(
        title: 'SpotGo Parking Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: ListenableBuilder(
          listenable: _auth,
          builder: (context, _) {
            final account = _auth.account;
            if (account == null) {
              return LoginScreen(showDemoHint: widget.authRepository == null);
            }
            return AdminShell(
              key: ValueKey(account.id),
              account: account,
              repository: _parkingRepository,
              liveRefreshInterval: widget.liveRefreshInterval,
            );
          },
        ),
      ),
    );
  }
}
