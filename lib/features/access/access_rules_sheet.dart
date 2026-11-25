import 'package:flutter/material.dart';

/// Bottom sheet that explains the zone scope of the Administrator's access
/// rules (mockup 31a).
Future<void> showAccessRulesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Access rules',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'This Administrator manages Javier Prado Parking only. Driver '
              'access and spot rules apply only to this assigned zone.',
              style: Theme.of(sheetContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('Review access settings'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    ),
  );
}
