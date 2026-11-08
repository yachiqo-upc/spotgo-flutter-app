import 'package:flutter/material.dart';

import 'app_scope.dart';

/// Pushes a full-screen page (forms and details) on the root navigator,
/// keeping access to the current [AdminScope] that lives below it.
Future<T?> pushAdminPage<T>(BuildContext context, Widget page) {
  final scope = context.getInheritedWidgetOfExactType<AdminScope>();
  assert(scope != null, 'pushAdminPage needs an AdminScope ancestor');
  final controller = scope!.notifier!;
  return Navigator.of(context, rootNavigator: true).push<T>(
    MaterialPageRoute(
      builder: (_) => AdminScope(controller: controller, child: page),
    ),
  );
}
