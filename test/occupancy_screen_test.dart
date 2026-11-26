import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spotgo_mobile_app/app/spotgo_admin_app.dart';
import 'package:spotgo_mobile_app/data/mock/mock_auth_repository.dart';
import 'package:spotgo_mobile_app/data/mock/mock_parking_repository.dart';

void main() {
  testWidgets('loads physical occupancy and exposes no-sensor registration', (
    tester,
  ) async {
    await tester.pumpWidget(
      SpotGoAdminApp(
        authRepository: MockAuthRepository(latency: Duration.zero),
        parkingRepository: MockParkingRepository(latency: Duration.zero),
        liveRefreshInterval: null,
      ),
    );
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'admin@spotgo.pe',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'SpotGo2026!',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Occupancy').last);
    await tester.pumpAndSettle();
    expect(find.text('Live occupancy'), findsOneWidget);

    final spot = find.byKey(const Key('spot-A-08'));
    await tester.ensureVisible(spot);
    await tester.tap(spot);
    await tester.pumpAndSettle();
    expect(find.text('Register HTTP sensor'), findsOneWidget);
    expect(find.text('NO_ACTIVE_SENSOR'), findsOneWidget);
  });
}
