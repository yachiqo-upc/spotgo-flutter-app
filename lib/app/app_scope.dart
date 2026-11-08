import 'package:flutter/widgets.dart';

import '../state/auth_controller.dart';

/// Exposes the app controllers to the widget tree without extra packages.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.auth, required super.child});

  final AuthController auth;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in the widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => auth != oldWidget.auth;
}
