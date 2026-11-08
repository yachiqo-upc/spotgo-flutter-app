import 'package:flutter/material.dart';

import '../../app/admin_navigation.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/choice_chip_bar.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/parking_spot.dart';
import '../../data/models/parking_zone.dart';
import '../guests/new_guest_session_screen.dart';
import '../shell/account_sheet.dart';
import 'spot_widgets.dart';

enum SpotFilter { all, available, issues }

/// Live occupancy map grouped by zone (mockup 16, US05 and US07 scenario 2).
class OccupancyScreen extends StatefulWidget {
  const OccupancyScreen({super.key});

  @override
  State<OccupancyScreen> createState() => _OccupancyScreenState();
}

class _OccupancyScreenState extends State<OccupancyScreen> {
  final _searchController = TextEditingController();
  SpotFilter _filter = SpotFilter.all;
  String? _zoneId;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(ParkingSpot spot) {
    if (_query.isNotEmpty &&
        !spot.code.toLowerCase().contains(_query.toLowerCase())) {
      return false;
    }
    return switch (_filter) {
      SpotFilter.all => true,
      SpotFilter.available => spot.availability == SpotAvailability.available,
      SpotFilter.issues =>
        spot.hasIssue || spot.availability == SpotAvailability.unavailable,
    };
  }

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final zones = admin.zones
        .where((z) => _zoneId == null || z.id == _zoneId)
        .toList();
    final scopeSpots = _zoneId == null
        ? admin.spots
        : admin.spotsOfZone(_zoneId!);
    final occupied = scopeSpots
        .where((s) => s.availability == SpotAvailability.occupied)
        .length;
    final available = scopeSpots
        .where((s) => s.availability == SpotAvailability.available)
        .length;
    final unassigned = _zoneId == null
        ? admin.spots.where((s) => admin.zoneById(s.zoneId) == null).toList()
        : const <ParkingSpot>[];
    final groups = <({String title, List<ParkingSpot> spots, int total})>[
      for (final zone in zones)
        (
          title: zone.name,
          spots: admin.spotsOfZone(zone.id).where(_matches).toList(),
          total: zone.totalSpots,
        ),
      if (unassigned.isNotEmpty)
        (
          title: 'Unassigned spots',
          spots: unassigned.where(_matches).toList(),
          total: unassigned.length,
        ),
    ].where((g) => g.spots.isNotEmpty).toList();
    final updatedAt = admin.snapshot?.updatedAt ?? admin.now;
    final scopeName = _zoneId == null
        ? 'All zones'
        : admin.zoneById(_zoneId!)?.name ?? 'Zone';

    return RefreshIndicator(
      onRefresh: admin.refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: PageContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                title: 'Live occupancy',
                subtitle: '${admin.facilityName} · real-time spot status',
                onProfileTap: () => showAccountSheet(context),
              ),
              TextField(
                key: const Key('spot-search'),
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value.trim()),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search parking spot',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ChoiceChipBar<SpotFilter>(
                options: const [
                  ChipOption(SpotFilter.all, 'All'),
                  ChipOption(SpotFilter.available, 'Available'),
                  ChipOption(SpotFilter.issues, 'Issues'),
                ],
                selected: _filter,
                onSelected: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 8),
              ChoiceChipBar<String?>(
                options: [
                  const ChipOption(null, 'All zones'),
                  for (final zone in admin.zones) ChipOption(zone.id, zone.name),
                ],
                selected: _zoneId,
                onSelected: (value) => setState(() => _zoneId = value),
              ),
              const SizedBox(height: 12),
              const SpotLegend(),
              const SizedBox(height: 12),
              if (groups.isEmpty)
                const Card(
                  child: EmptyView(
                    icon: Icons.search_off,
                    title: 'No spots match the filters',
                    message: 'Change the filter or search another code.',
                  ),
                )
              else
                for (final group in groups) ...[
                  ZoneSpotsCard(
                    title: group.title,
                    totalSpots: group.total,
                    spots: group.spots,
                    showLane: _filter == SpotFilter.all && _query.isEmpty,
                    onSpotTap: (spot) => showSpotDetails(context, spot),
                  ),
                  const SizedBox(height: 12),
                ],
              _LiveSummaryCard(
                title: '${admin.facilityName} · $scopeName',
                occupied: occupied,
                total: scopeSpots.length,
                available: available,
                updatedAt: updatedAt,
                stale: admin.error != null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveSummaryCard extends StatelessWidget {
  const _LiveSummaryCard({
    required this.title,
    required this.occupied,
    required this.total,
    required this.available,
    required this.updatedAt,
    required this.stale,
  });

  final String title;
  final int occupied;
  final int total;
  final int available;
  final DateTime updatedAt;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    Widget figure(String value, String label, Color color) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                StatusBadge(
                  label: stale ? 'Delayed' : 'Live',
                  tone: stale ? BadgeTone.warning : BadgeTone.success,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: figure(
                    '$occupied / $total',
                    'occupied',
                    AppColors.primary,
                  ),
                ),
                Expanded(
                  child: figure('$available', 'available', AppColors.success),
                ),
                Expanded(
                  child: figure(
                    Formatters.time(updatedAt),
                    'last update',
                    AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with the independent occupancy, reservation and sensor states.
Future<void> showSpotDetails(BuildContext context, ParkingSpot spot) {
  final admin = AdminScope.of(context);
  final ParkingZone? zone = admin.zoneById(spot.zoneId);
  final session = spot.guestSessionId == null
      ? null
      : admin.sessionById(spot.guestSessionId!);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Spot ${spot.code}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                StatusBadge(
                  label: spot.hasUnvalidatedOccupancy
                      ? 'Unvalidated'
                      : spot.availability.label,
                  tone: availabilityTone(spot),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${zone?.name ?? 'Unassigned'} · ${spot.type.label} spot',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SpotStateTable(spot: spot, guestPlate: session?.plate),
            const SizedBox(height: 12),
            if (!spot.sensorReliable)
              const SpotNotice(
                'Sensor data is not reliable. The spot stays Unavailable and '
                'reservations and guest sessions are blocked until reliable '
                'readings return.',
              )
            else if (spot.hasUnvalidatedOccupancy)
              const SpotNotice(
                'Occupied without an active reservation or guest session. '
                'Review the unauthorized occupancy alert. Vehicles are not '
                'identified by image or plate.',
              ),
            if (spot.canStartGuestSession && (zone?.isActive ?? false)) ...[
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('spot-start-guest'),
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  pushAdminPage<void>(
                    context,
                    NewGuestSessionScreen(initialSpotId: spot.id),
                  );
                },
                child: const Text('Start guest session here'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
