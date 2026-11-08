import 'package:flutter/widgets.dart';

import '../data/repositories/parking_repository.dart';
import '../state/admin_controller.dart';
import '../state/auth_controller.dart';

/// Exposes the app-wide dependencies without extra packages.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.auth,
    required this.parkingRepository,
    required super.child,
  });

  final AuthController auth;
  final ParkingRepository parkingRepository;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in the widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      auth != oldWidget.auth ||
      parkingRepository != oldWidget.parkingRepository;
}

/// Provides the signed in admin's [AdminController]; dependents rebuild
/// whenever it notifies.
class AdminScope extends InheritedNotifier<AdminController> {
  const AdminScope({
    super.key,
    required AdminController controller,
    required super.child,
  }) : super(notifier: controller);

  static AdminController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AdminScope>();
    assert(scope != null, 'AdminScope not found in the widget tree');
    return scope!.notifier!;
  }
}
