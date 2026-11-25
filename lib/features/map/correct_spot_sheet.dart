import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Bottom sheet that lets the Administrator fix an unclear spot boundary
/// before publishing the map (mockup 25a).
Future<void> showCorrectSpotSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _CorrectSpotSheet(),
  );
}

class _CorrectSpotSheet extends StatefulWidget {
  const _CorrectSpotSheet();

  @override
  State<_CorrectSpotSheet> createState() => _CorrectSpotSheetState();
}

class _CorrectSpotSheetState extends State<_CorrectSpotSheet> {
  late final _spot = TextEditingController(text: 'A-06');
  late final _type = TextEditingController(text: 'Standard');
  late final _sensor = TextEditingController(text: 'SEN-JP-A06');

  @override
  void dispose() {
    for (final c in [_spot, _type, _sensor]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Correct spot manually',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Review unclear boundaries before publishing.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _spot,
              decoration: const InputDecoration(labelText: 'Spot'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _type,
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _sensor,
              decoration: const InputDecoration(labelText: 'Sensor ID'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sensor data pending · Spot stays Unavailable',
              style: TextStyle(color: AppColors.warning, fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('spot-correction-save'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Correction saved')),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Validate & save correction'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
