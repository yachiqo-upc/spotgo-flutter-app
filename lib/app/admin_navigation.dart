import 'package:flutter/material.dart';

import 'app_scope.dart';

/// Pushes a page keeping access to the current [AdminScope], since routes
/// are inserted above the shell in the root navigator.
Future<T?> pushAdminPage<T>(BuildContext context, Widget page) {
  final scope = context.getInheritedWidgetOfExactType<AdminScope>();
  assert(scope != null, 'pushAdminPage needs an AdminScope ancestor');
  final controller = scope!.notifier!;
  return Navigator.of(context).push<T>(
    MaterialPageRoute(
      builder: (_) => AdminScope(controller: controller, child: page),
    ),
  );
}
