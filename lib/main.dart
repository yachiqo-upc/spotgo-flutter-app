import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/spotgo_admin_app.dart';
import 'data/remote/remote_auth_repository.dart';
import 'data/remote/remote_billing_repository.dart';
import 'data/remote/remote_monitoring_repository.dart';
import 'data/remote/remote_parking_repository.dart';
import 'data/remote/spotgo_api.dart';

void main() {
  const baseUrl = String.fromEnvironment(
    'SPOTGO_API_BASE_URL',
    defaultValue: kDebugMode ? 'http://10.0.2.2:8080' : '',
  );
  final uri = Uri.tryParse(baseUrl.trim());
  final validUrl =
      uri != null &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      (uri.scheme == 'https' || kDebugMode && uri.scheme == 'http');
  if (!validUrl) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Configure the SpotGo backend with SPOTGO_API_BASE_URL.',
            ),
          ),
        ),
      ),
    );
    return;
  }

  final api = SpotGoApi(uri);
  runApp(
    SpotGoAdminApp(
      authRepository: RemoteAuthRepository(api),
      parkingRepository: RemoteParkingRepository(api),
      billingRepository: RemoteBillingRepository(api),
      monitoringRepository: RemoteMonitoringRepository(api),
    ),
  );
}
