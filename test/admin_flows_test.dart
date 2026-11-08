import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spotgo_mobile_app/app/spotgo_admin_app.dart';
import 'package:spotgo_mobile_app/data/mock/mock_auth_repository.dart';
import 'package:spotgo_mobile_app/data/mock/mock_parking_repository.dart';

Widget _app() => SpotGoAdminApp(
  authRepository: MockAuthRepository(latency: Duration.zero),
  parkingRepository: MockParkingRepository(latency: Duration.zero),
  liveRefreshInterval: null,
);

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('login-email')), 'admin@spotgo.pe');
  await tester.enterText(find.byKey(const Key('login-password')), 'SpotGo2026!');
  final submit = find.byKey(const Key('login-submit'));
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

Future<void> _selectTab(WidgetTester tester, String label) async {
  final tab = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login reaches the dashboard and its live metrics', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await _signIn(tester);

    expect(find.text('Administrator dashboard'), findsOneWidget);
    expect(find.byKey(const Key('metric-occupancy')), findsOneWidget);
    expect(find.byKey(const Key('metric-available')), findsOneWidget);
    expect(find.byKey(const Key('metric-alerts')), findsOneWidget);
    expect(find.byKey(const Key('metric-guests')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Critical alert can be classified and resolved', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await _signIn(tester);
    await _selectTab(tester, 'Alerts');

    final critical = find.byKey(const Key('alert-filter-critical'));
    await tester.ensureVisible(critical);
    await tester.tap(critical);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('alert-card-AL-2001')), findsOneWidget);
    expect(find.byKey(const Key('alert-card-AL-2005')), findsOneWidget);
    expect(find.byKey(const Key('alert-card-AL-2003')), findsNothing);

    final card = find.byKey(const Key('alert-card-AL-2001'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('Alert detail'), findsOneWidget);

    final classification = find.byKey(const Key('alert-change-classification'));
    await tester.ensureVisible(classification);
    await tester.tap(classification);
    await tester.pumpAndSettle();
    final sensorOffline = find.text('Sensor offline').last;
    await tester.ensureVisible(sensorOffline);
    await tester.tap(sensorOffline);
    await tester.pumpAndSettle();

    final action = find.byKey(const Key('alert-action'));
    await tester.ensureVisible(action);
    await tester.enterText(action, 'Replaced the sensor');
    final resolvedChoice = find.text('Resolved');
    await tester.ensureVisible(resolvedChoice);
    await tester.tap(resolvedChoice);
    await tester.pumpAndSettle();
    final submit = find.byKey(const Key('alert-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('alert-card-AL-2001')), findsNothing);
    final resolvedFilter = find.byKey(const Key('alert-filter-resolved'));
    await tester.ensureVisible(resolvedFilter);
    await tester.tap(resolvedFilter);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('alert-card-AL-2001')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('More creates a guest session and closes it after payment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await _signIn(tester);
    await _selectTab(tester, 'More');

    final guests = find.byKey(const Key('more-guests'));
    await tester.ensureVisible(guests);
    await tester.tap(guests);
    await tester.pumpAndSettle();
    expect(find.text('Guest parking sessions'), findsOneWidget);

    final newGuest = find.byKey(const Key('guest-new'));
    await tester.ensureVisible(newGuest);
    await tester.tap(newGuest);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('guest-plate')), 'Z9Q-731');

    final spot = find.byKey(const Key('guest-spot'));
    await tester.ensureVisible(spot);
    await tester.tap(spot);
    await tester.pumpAndSettle();
    final availableSpot = find.text('A-01 · Standard · Available').last;
    await tester.ensureVisible(availableSpot);
    await tester.tap(availableSpot);
    await tester.pumpAndSettle();

    final start = find.byKey(const Key('guest-start'));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    final plate = find.text('Z9Q-731');
    expect(plate, findsOneWidget);
    await tester.ensureVisible(plate);
    await tester.tap(plate);
    await tester.pumpAndSettle();

    final exit = find.byKey(const Key('guest-register-exit'));
    await tester.ensureVisible(exit);
    await tester.tap(exit);
    await tester.pumpAndSettle();
    expect(find.text('Amount due'), findsOneWidget);

    final collected = find.byKey(const Key('guest-collected'));
    await tester.ensureVisible(collected);
    await tester.tap(collected);
    await tester.pumpAndSettle();
    final confirm = find.byKey(const Key('guest-confirm-payment'));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('Payment confirmed'), findsOneWidget);
    expect(find.text('Session closed'), findsOneWidget);
    expect(find.byKey(const Key('guest-confirm-payment')), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
