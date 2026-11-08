import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spotgo_mobile_app/app/spotgo_admin_app.dart';
import 'package:spotgo_mobile_app/data/mock/mock_auth_repository.dart';

void main() {
  testWidgets('shows the Parking Admin sign in without public sign up', (
    tester,
  ) async {
    await tester.pumpWidget(
      SpotGoAdminApp(authRepository: MockAuthRepository(latency: Duration.zero)),
    );

    expect(find.text('Sign in'), findsWidgets);
    expect(find.textContaining('Create account'), findsNothing);
  });

  testWidgets('rejects invalid credentials', (tester) async {
    await tester.pumpWidget(
      SpotGoAdminApp(authRepository: MockAuthRepository(latency: Duration.zero)),
    );

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'admin@spotgo.pe',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'wrong-password',
    );
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
  });
}
