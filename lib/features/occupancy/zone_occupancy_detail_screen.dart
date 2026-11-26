import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/choice_chip_bar.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/parking_spot.dart';
import '../../data/repositories/monitoring_repository.dart';
import '../../state/monitoring_controller.dart';
import 'spot_widgets.dart';

enum _SpotFilter { all, available, occupied, issues }

class ZoneOccupancyDetailScreen extends StatefulWidget {
  const ZoneOccupancyDetailScreen({super.key, this.zoneId});

  final String? zoneId;

  @override
  State<ZoneOccupancyDetailScreen> createState() =>
      _ZoneOccupancyDetailScreenState();
}

class _ZoneOccupancyDetailScreenState extends State<ZoneOccupancyDetailScreen> {
  _SpotFilter _filter = _SpotFilter.all;

  bool _matches(ParkingSpot spot) => switch (_filter) {
    _SpotFilter.all => true,
    _SpotFilter.available => spot.occupancy == OccupancyStatus.available,
    _SpotFilter.occupied => spot.occupancy == OccupancyStatus.occupied,
    _SpotFilter.issues =>
      spot.occupancy == OccupancyStatus.unavailable || spot.hasIssue,
  };

  Future<void> _openSpot(
    BuildContext context,
    MonitoringController monitoring,
    ParkingSpot spot,
  ) async {
    if (monitoring.forbidden) return;
    try {
      final observation = await monitoring.occupancyForSpot(spot.id);
      if (!context.mounted) return;
      final sensor = monitoring.sensorForSpot(spot.id);
      await showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Spot ${spot.code}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                InfoRow(
                  title: 'Physical occupancy',
                  trailing: observation.occupancy.name,
                ),
                InfoRow(
                  title: 'Reason',
                  trailing: observation.reason.isEmpty
                      ? '—'
                      : observation.reason,
                ),
                InfoRow(
                  title: 'Sensor',
                  trailing: sensor?.status.name ?? 'No active sensor',
                ),
                InfoRow(
                  title: 'Last reading',
                  trailing: observation.occurredAt?.toLocal().toString() ?? '—',
                ),
              ],
            ),
          ),
        ),
      );
    } on MonitoringException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final monitoring = AppScope.of(context).monitoring;
    final zone = admin.zoneById(widget.zoneId ?? '') ?? admin.zones.firstOrNull;
    if (monitoring.forbidden) {
      return ErrorView(
        message: '${monitoring.error ?? 'Access denied.'} (HTTP 403)',
      );
    }
    if (zone == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Zone occupancy')),
        body: EmptyView(
          icon: Icons.location_off_outlined,
          title: 'No parking zones',
          message: 'No zones are assigned to this parking tenant.',
        ),
      );
    }
    final spots = admin.spotsOfZone(zone.id).where(_matches).toList();
    final zoneSpots = admin.spotsOfZone(zone.id);
    final occupied = zoneSpots
        .where((spot) => spot.occupancy == OccupancyStatus.occupied)
        .length;
    final available = zoneSpots
        .where((spot) => spot.occupancy == OccupancyStatus.available)
        .length;
    final unavailable = zoneSpots
        .where(
          (spot) =>
              spot.occupancy == OccupancyStatus.unavailable ||
              spot.occupancy == OccupancyStatus.unknown,
        )
        .length;

    return ListenableBuilder(
      listenable: monitoring,
      builder: (context, _) {
        if (monitoring.forbidden) {
          return ErrorView(
            message: '${monitoring.error ?? 'Access denied.'} (HTTP 403)',
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(zone.name)),
          body: SafeArea(
            child: ListView(
              children: [
                PageContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        admin.facilityName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Physical occupancy · ${admin.snapshot?.updatedAt.toLocal() ?? admin.now.toLocal()}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Metric(
                            value: '$occupied',
                            label: 'Occupied',
                            color: AppColors.danger,
                          ),
                          _Metric(
                            value: '$available',
                            label: 'Available',
                            color: AppColors.success,
                          ),
                          _Metric(
                            value: '$unavailable',
                            label: 'Unavailable',
                            color: AppColors.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ChoiceChipBar<_SpotFilter>(
                        options: const [
                          ChipOption(_SpotFilter.all, 'All'),
                          ChipOption(_SpotFilter.available, 'Available'),
                          ChipOption(_SpotFilter.occupied, 'Occupied'),
                          ChipOption(_SpotFilter.issues, 'Issues'),
                        ],
                        selected: _filter,
                        onSelected: (value) => setState(() => _filter = value),
                      ),
                      const SizedBox(height: 14),
                      if (zoneSpots.isEmpty)
                        const Card(
                          child: EmptyView(
                            title: 'This zone has no spots',
                            message:
                                'Add parking spots to view physical occupancy.',
                          ),
                        )
                      else if (spots.isEmpty)
                        const Card(
                          child: EmptyView(
                            title: 'No spots match this filter',
                            message: 'Choose another occupancy filter.',
                          ),
                        )
                      else
                        ZoneSpotsCard(
                          title: zone.name,
                          totalSpots: zoneSpots.length,
                          spots: spots,
                          onSpotTap: (spot) =>
                              _openSpot(context, monitoring, spot),
                        ),
                      if (monitoring.error != null)
                        Card(
                          child: ListTile(
                            title: Text(
                              '${monitoring.error}'
                              '${monitoring.errorStatus == null ? '' : ' (HTTP ${monitoring.errorStatus})'}',
                            ),
                            trailing: IconButton(
                              onPressed: monitoring.loading
                                  ? null
                                  : monitoring.load,
                              icon: const Icon(Icons.refresh),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

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
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(label),
        ],
      ),
    ),
  );
}
