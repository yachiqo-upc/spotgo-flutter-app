import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/choice_chip_bar.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/status_badge.dart';
import 'correct_spot_sheet.dart';

/// Interactive floor plan of a level where every spot keeps its type and
/// Sensor ID before publishing (mockup 25).
class DigitalParkingMapScreen extends StatefulWidget {
  const DigitalParkingMapScreen({super.key});

  @override
  State<DigitalParkingMapScreen> createState() =>
      _DigitalParkingMapScreenState();
}

class _DigitalParkingMapScreenState extends State<DigitalParkingMapScreen> {
  _SpotFilter _filter = _SpotFilter.all;
  String _selectedId = 'A-06';

  static const _spots = [
    _Spot('A-01', 'STD', pending: true),
    _Spot('A-02', 'STD', pending: true),
    _Spot('A-03', 'EV', pending: true),
    _Spot('A-04', 'ACC', pending: true),
    _Spot('A-05', 'STD', pending: true),
    _Spot('A-06', 'STD', pending: true),
    _Spot('A-07', 'STD', pending: true),
    _Spot('A-08', 'STD', pending: true),
  ];

  bool _visible(_Spot spot) => switch (_filter) {
    _SpotFilter.all => true,
    _SpotFilter.standard => spot.type == 'STD',
    _SpotFilter.ev => spot.type == 'EV',
    _SpotFilter.accessible => spot.type == 'ACC',
  };

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final visible = _spots.where(_visible).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Digital parking map')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${admin.facilityName} · Level 1',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Assign each space, type and sensor before publishing.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                ChoiceChipBar<_SpotFilter>(
                  options: const [
                    ChipOption(_SpotFilter.all, 'All'),
                    ChipOption(_SpotFilter.standard, 'Standard'),
                    ChipOption(_SpotFilter.ev, 'EV'),
                    ChipOption(_SpotFilter.accessible, 'Accessible'),
                  ],
                  selected: _filter,
                  onSelected: (value) => setState(() => _filter = value),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'LEVEL 01',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              '${visible.length} draft spots',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _SpotRow(
                          spots: visible.take(4).toList(),
                          selectedId: _selectedId,
                          onSelect: (id) => setState(() => _selectedId = id),
                        ),
                        const SizedBox(height: 14),
                        const _Lane(),
                        const SizedBox(height: 14),
                        _SpotRow(
                          spots: visible.skip(4).toList(),
                          selectedId: _selectedId,
                          onSelect: (id) => setState(() => _selectedId = id),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SpotDetailCard(
                  spot: _spots.firstWhere(
                    (s) => s.code == _selectedId,
                    orElse: () => _spots.first,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('spot-correct-manually'),
                  onPressed: () => showCorrectSpotSheet(context),
                  child: const Text('Correct spot manually'),
                ),
                const SizedBox(height: 12),
                const NoticeCard(
                  title: 'Publish only a validated map',
                  message:
                      'Each spot needs a type and Sensor ID. New spots stay '
                      'Unavailable until reliable sensor data arrives. If the '
                      'floor plan is unclear, correct it manually before '
                      'publishing.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Map validated and published'),
                    ),
                  ),
                  child: const Text('Publish map'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _SpotFilter { all, standard, ev, accessible }

class _Spot {
  const _Spot(this.code, this.type, {required this.pending});

  final String code;
  final String type;
  final bool pending;
}

class _SpotRow extends StatelessWidget {
  const _SpotRow({
    required this.spots,
    required this.selectedId,
    required this.onSelect,
  });

  final List<_Spot> spots;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final spot in spots) ...[
          Expanded(
            child: _SpotTile(
              spot: spot,
              selected: spot.code == selectedId,
              onTap: () => onSelect(spot.code),
            ),
          ),
          if (spot != spots.last) const SizedBox(width: 8),
        ],
        for (var i = spots.length; i < 4; i++) ...[
          const Expanded(child: SizedBox()),
          if (i < 3) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _SpotTile extends StatelessWidget {
  const _SpotTile({
    required this.spot,
    required this.selected,
    required this.onTap,
  });

  final _Spot spot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.success : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              spot.code,
              style: TextStyle(
                color: selected ? AppColors.onPrimary : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              spot.type,
              style: TextStyle(
                color: selected ? AppColors.onPrimary : AppColors.textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              selected ? '• Selected' : '• Pending',
              style: TextStyle(
                color: selected ? AppColors.onPrimary : AppColors.warning,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Drive lane between both spot rows, with ENTRY and EXIT markers.
class _Lane extends StatelessWidget {
  const _Lane();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(height: 2, color: AppColors.border),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: AppColors.textMuted,
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ENTRY',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            Text(
              'EXIT',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

class _SpotDetailCard extends StatelessWidget {
  const _SpotDetailCard({required this.spot});

  final _Spot spot;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Spot ${spot.code}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const StatusBadge(label: 'Unavailable', tone: BadgeTone.danger),
              ],
            ),
            const SizedBox(height: 14),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Type'),
              child: Text(
                spot.type == 'STD'
                    ? 'Standard'
                    : spot.type == 'EV'
                    ? 'EV'
                    : 'Accessible',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Sensor ID'),
              child: Text(
                'SEN-JP-${spot.code}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
