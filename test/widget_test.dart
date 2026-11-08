import 'package:flutter_test/flutter_test.dart';

import 'package:spotgo_mobile_app/core/widgets/spotgo_logo.dart';
import 'package:spotgo_mobile_app/main.dart';

void main() {
  testWidgets('app starts with the SpotGo theme', (tester) async {
    await tester.pumpWidget(const SpotGoAdminApp());

    expect(find.byType(SpotGoLogo), findsOneWidget);
  });
}
