import 'package:flutter/material.dart';

import '../../app/admin_navigation.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/choice_chip_bar.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/status_badge.dart';
import '../guests/new_guest_session_screen.dart';

/// Live status of one zone with a tappable spot list (mockup 32).
class ZoneOccupancyDetailScreen extends StatefulWidget {
  const ZoneOccupancyDetailScreen({super.key});

  @override
  State<ZoneOccupancyDetailScreen> createState() =>
      _ZoneOccupancyDetailScreenState();
}

class _ZoneOccupancyDetailScreenState
    extends State<ZoneOccupancyDetailScreen> {
  _SpotFilter _filter = _SpotFilter.all;

  static const _spots = [
    _SpotRow('A-01', 'Available', 'No reservation · Sensor healthy',
        BadgeTone.success, 'Available'),
    _SpotRow('A-02', 'Occupied', 'Reservation SG-4817 · Sensor healthy',
        BadgeTone.neutral, 'Occupied'),
    _SpotRow('A-03', 'Unavailable', 'Sensor offline · New sessions blocked',
        BadgeTone.danger, 'Issue'),
    _SpotRow('A-04', 'Occupied', 'Guest GP-1048 · Sensor healthy',
        BadgeTone.neutral, 'Occupied'),
    _SpotRow('A-05', 'Available', 'Reserved SG-4825 · New sessions blocked',
        BadgeTone.warning, 'Reserved'),
    _SpotRow('A-06', 'Available', 'No reservation · Sensor healthy',
        BadgeTone.success, 'Available'),
  ];

  bool _visible(_SpotRow spot) => switch (_filter) {
    _SpotFilter.all => true,
    _SpotFilter.profile => spot.state == 'Reserved',
    _SpotFilter.occupied => spot.state == 'Occupied',
    _SpotFilter.issues => spot.state == 'Issue',
  };

  void _openDetails(_SpotRow spot) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _SpotDetailsSheet(spot: spot),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final visible = _spots.where(_visible).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Zone occupancy')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  admin.facilityName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Level 1 · Last updated 5 seconds ago',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        value: '14',
                        label: 'Occupied',
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _Metric(
                        value: '6',
                        label: 'Available',
                        color: AppColors.success,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _Metric(
                        value: '2',
                        label: 'Reserved',
                        color: AppColors.warning,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _Metric(
                        value: '2',
                        label: 'Unavailable',
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live status for your assigned zone',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tap a spot for Occupancy, Reservation, Guest Session '
                        'and Sensor Health.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ChoiceChipBar<_SpotFilter>(
                  options: const [
                    ChipOption(_SpotFilter.all, 'All'),
                    ChipOption(_SpotFilter.profile, 'Profile'),
                    ChipOption(_SpotFilter.occupied, 'Occupied'),
                    ChipOption(_SpotFilter.issues, 'Issues'),
                  ],
                  selected: _filter,
                  onSelected: (value) => setState(() => _filter = value),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  children: [
                    for (final spot in visible)
                      InfoRow(
                        title: '${spot.code} · ${spot.state}',
                        subtitle: spot.detail,
                        trailingWidget: StatusBadge(
                          label: spot.badge,
                          tone: spot.tone,
                        ),
                        onTap: () => _openDetails(spot),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _SpotFilter { all, profile, occupied, issues }

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SpotRow {
  const _SpotRow(this.code, this.state, this.detail, this.tone, this.badge);

  final String code;
  final String state;
  final String detail;
  final BadgeTone tone;
  final String badge;
}

/// Bottom sheet with the four spot attributes from the mockup.
class _SpotDetailsSheet extends StatelessWidget {
  const _SpotDetailsSheet({required this.spot});

  final _SpotRow spot;

  @override
  Widget build(BuildContext context) {
    final available = spot.state == 'Available';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Spot details', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Javier Prado Parking · Level 1',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Spot ${spot.code}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _DetailRow(
              label: 'Occupancy Status',
              value: spot.state,
            ),
            _DetailRow(
              label: 'Reservation Status',
              value: spot.state == 'Occupied' ? 'SG-4817' : 'None',
            ),
            _DetailRow(
              label: 'Guest Session',
              value: spot.state == 'Occupied' ? 'GP-1048' : 'None',
            ),
            _DetailRow(
              label: 'Sensor Health',
              value: spot.state == 'Unavailable' ? 'Offline' : 'Healthy',
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: available
                  ? () {
                      Navigator.of(context).pop();
                      pushAdminPage<void>(
                        context,
                        const NewGuestSessionScreen(),
                      );
                    }
                  : null,
              child: const Text('New Guest Session'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
