import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spotgo_mobile_app/app/spotgo_admin_app.dart';
import 'package:spotgo_mobile_app/data/mock/mock_auth_repository.dart';
import 'package:spotgo_mobile_app/data/mock/mock_parking_repository.dart';

Widget buildApp() => SpotGoAdminApp(
  authRepository: MockAuthRepository(latency: Duration.zero),
  parkingRepository: MockParkingRepository(latency: Duration.zero),
  liveRefreshInterval: null,
);

Future<void> signIn(WidgetTester tester, {String password = 'SpotGo2026!'}) async {
  await tester.enterText(find.byKey(const Key('login-email')), 'admin@spotgo.pe');
  await tester.enterText(find.byKey(const Key('login-password')), password);
  await tester.ensureVisible(find.byKey(const Key('login-submit')));
  await tester.tap(find.byKey(const Key('login-submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the Parking Admin sign in without public sign up', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());

    expect(find.text('Sign in'), findsWidgets);
    expect(find.textContaining('Create account'), findsNothing);
  });

  testWidgets('rejects invalid credentials', (tester) async {
    await tester.pumpWidget(buildApp());
    await signIn(tester, password: 'wrong-password');

    expect(find.text('Invalid email or password.'), findsOneWidget);
  });

  testWidgets('valid admin reaches the navigation shell and can sign out', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await signIn(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('More'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Audit history'), findsOneWidget);

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
  });
}
