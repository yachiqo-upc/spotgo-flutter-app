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
import '../../domain/parking_rules.dart';
import '../../data/models/monitoring.dart';
import '../../data/repositories/monitoring_repository.dart';
import '../../state/monitoring_controller.dart';
import '../billing/plans_screen.dart';
import '../guests/new_guest_session_screen.dart';
import '../shell/account_sheet.dart';
import 'zone_occupancy_detail_screen.dart';
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
      SpotFilter.available => spot.occupancy == OccupancyStatus.available,
      SpotFilter.issues =>
        spot.hasIssue || spot.availability == SpotAvailability.unavailable,
    };
  }

  Future<void> _monitorAction(Future<Object?> Function() action) async {
    try {
      await action();
    } on MonitoringException {
      if (mounted) setState(() {});
    }
  }

  Future<void> _closeAlert(
    MonitoringController monitoring,
    OccupancyAlert alert,
  ) async {
    final actionController = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close occupancy alert'),
        content: TextField(
          controller: actionController,
          maxLength: 1000,
          decoration: const InputDecoration(labelText: 'Resolution action'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, actionController.text),
            child: const Text('Close alert'),
          ),
        ],
      ),
    );
    actionController.dispose();
    if (action == null || action.trim().isEmpty) return;
    await _monitorAction(
      () => monitoring.closeAlert(
        alertId: alert.alertId,
        classification: ResolutionClassification.other,
        action: action,
      ),
    );
  }

  Future<void> _showEvidence(
    MonitoringController monitoring,
    OccupancyAlert alert,
  ) async {
    try {
      final bytes = await monitoring.evidence(alert.alertId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Alert evidence'),
          content: Image.memory(bytes, fit: BoxFit.contain),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on MonitoringException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final monitoring = AppScope.of(context).monitoring;
    final zones = admin.zones
        .where((z) => _zoneId == null || z.id == _zoneId)
        .toList();
    final scopeSpots = _zoneId == null
        ? admin.spots
        : admin.spotsOfZone(_zoneId!);
    final occupied = ParkingRules.physicallyOccupied(scopeSpots);
    final available = scopeSpots
        .where((s) => s.occupancy == OccupancyStatus.available)
        .length;
    final unassigned = _zoneId == null
        ? admin.spots.where((s) => admin.zoneById(s.zoneId) == null).toList()
        : const <ParkingSpot>[];
    final groups =
        <({String title, String? zoneId, List<ParkingSpot> spots, int total})>[
          for (final zone in zones)
            (
              title: zone.name,
              zoneId: zone.id,
              spots: admin.spotsOfZone(zone.id).where(_matches).toList(),
              total: zone.totalSpots,
            ),
          if (unassigned.isNotEmpty)
            (
              title: 'Unassigned spots',
              zoneId: null,
              spots: unassigned.where(_matches).toList(),
              total: unassigned.length,
            ),
        ].where((g) => g.spots.isNotEmpty).toList();
    final updatedAt = admin.snapshot?.updatedAt ?? admin.now;
    final scopeName = _zoneId == null
        ? 'All zones'
        : admin.zoneById(_zoneId!)?.name ?? 'Zone';

    return ListenableBuilder(
      listenable: monitoring,
      builder: (context, _) {
        if (monitoring.forbidden) {
          return ErrorView(
            message: '${monitoring.error ?? 'Access denied.'} (HTTP 403)',
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([admin.refresh(), monitoring.refresh()]);
          },
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
                      for (final zone in admin.zones)
                        ChipOption(zone.id, zone.name),
                    ],
                    selected: _zoneId,
                    onSelected: (value) => setState(() => _zoneId = value),
                  ),
                  const SizedBox(height: 12),
                  const SpotLegend(),
                  const SizedBox(height: 12),
                  if (monitoring.error != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.cloud_off),
                        title: Text(
                          '${monitoring.error}'
                          '${monitoring.errorStatus == null ? '' : ' (HTTP ${monitoring.errorStatus})'}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Retry monitoring',
                          onPressed: monitoring.loading
                              ? null
                              : monitoring.load,
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    ),
                  if (admin.zones.isEmpty)
                    const Card(
                      child: EmptyView(
                        icon: Icons.location_off_outlined,
                        title: 'No parking zones',
                        message:
                            'No zones are assigned to this parking tenant.',
                      ),
                    )
                  else if (scopeSpots.isEmpty)
                    Card(
                      child: EmptyView(
                        icon: Icons.local_parking_outlined,
                        title: _zoneId == null
                            ? 'No parking spots'
                            : 'This zone has no spots',
                        message:
                            'Add parking spots to view physical occupancy.',
                      ),
                    )
                  else if (groups.isEmpty)
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
                        onTitleTap: group.zoneId == null
                            ? null
                            : () => pushAdminPage<void>(
                                context,
                                ZoneOccupancyDetailScreen(zoneId: group.zoneId),
                              ),
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
                    stale: admin.error != null || monitoring.error != null,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.sensors),
                          title: const Text('Monitoring sensors'),
                          subtitle: Text(
                            '${monitoring.sensors.where((s) => s.status == SensorStatus.active).length} active · '
                            '${monitoring.sensors.length} registered',
                          ),
                          trailing: IconButton(
                            tooltip: 'Record capacity snapshot',
                            onPressed: monitoring.loading
                                ? null
                                : () => _monitorAction(
                                    () => monitoring.createCapacitySnapshot(
                                      zoneId: _zoneId,
                                    ),
                                  ),
                            icon: const Icon(Icons.add_chart),
                          ),
                        ),
                        const Divider(height: 1),
                        for (final conflict in monitoring.conflicts)
                          if (conflict.status == MonitoringStatus.open ||
                              conflict.status == MonitoringStatus.acknowledged)
                            ListTile(
                              leading: const Icon(Icons.warning_amber_outlined),
                              title: Text(
                                '${conflict.conflictType.name} · ${conflict.spotId}',
                              ),
                              subtitle: Text(
                                '${conflict.severity} · ${conflict.status.name}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) => _monitorAction(
                                  () => action == 'acknowledge'
                                      ? monitoring.acknowledgeConflict(
                                          conflict.conflictId,
                                        )
                                      : monitoring.resolveConflict(
                                          conflict.conflictId,
                                        ),
                                ),
                                itemBuilder: (context) => [
                                  if (conflict.status == MonitoringStatus.open)
                                    const PopupMenuItem(
                                      value: 'acknowledge',
                                      child: Text('Acknowledge'),
                                    ),
                                  const PopupMenuItem(
                                    value: 'resolve',
                                    child: Text('Resolve'),
                                  ),
                                ],
                              ),
                            ),
                        for (final alert in monitoring.alerts)
                          if (alert.status == MonitoringStatus.open ||
                              alert.status == MonitoringStatus.acknowledged)
                            ListTile(
                              leading: const Icon(
                                Icons.notifications_active_outlined,
                              ),
                              title: Text(
                                '${alert.alertType.name} · ${alert.spotId}',
                              ),
                              subtitle: Text(
                                '${alert.severity} · ${alert.status.name}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) {
                                  if (action == 'acknowledge') {
                                    _monitorAction(
                                      () => monitoring.acknowledgeAlert(
                                        alert.alertId,
                                      ),
                                    );
                                  } else if (action == 'close') {
                                    _closeAlert(monitoring, alert);
                                  } else {
                                    _showEvidence(monitoring, alert);
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (alert.status == MonitoringStatus.open)
                                    const PopupMenuItem(
                                      value: 'acknowledge',
                                      child: Text('Acknowledge'),
                                    ),
                                  const PopupMenuItem(
                                    value: 'close',
                                    child: Text('Close'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'evidence',
                                    child: Text('View evidence'),
                                  ),
                                ],
                              ),
                            ),
                        for (final snapshot in monitoring.snapshots.take(3))
                          ListTile(
                            leading: const Icon(Icons.history),
                            title: Text(
                              '${snapshot.occupiedCount}/${snapshot.totalCount} occupied · ${snapshot.percentage}%',
                            ),
                            subtitle: Text(
                              snapshot.observedAt?.toLocal().toString() ??
                                  'Unknown time',
                            ),
                          ),
                        for (final alert in monitoring.capacityAlerts)
                          if (alert.status == MonitoringStatus.open)
                            ListTile(
                              leading: const Icon(Icons.pie_chart_outline),
                              title: Text(
                                'Capacity ${alert.occupancyPercentage}%'
                                '${alert.zoneId == null ? '' : ' · ${alert.zoneId}'}',
                              ),
                              subtitle: Text(
                                'Threshold ${alert.thresholdPercentage}%',
                              ),
                              trailing: IconButton(
                                tooltip: 'Acknowledge',
                                onPressed: () => _monitorAction(
                                  () => monitoring.acknowledgeCapacityAlert(
                                    alert.capacityAlertId,
                                  ),
                                ),
                                icon: const Icon(Icons.check),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
    builder: (_) =>
        _SpotDetailsSheet(spot: spot, zone: zone, guestPlate: session?.plate),
  );
}

class _SpotDetailsSheet extends StatefulWidget {
  const _SpotDetailsSheet({
    required this.spot,
    required this.zone,
    required this.guestPlate,
  });

  final ParkingSpot spot;
  final ParkingZone? zone;
  final String? guestPlate;

  @override
  State<_SpotDetailsSheet> createState() => _SpotDetailsSheetState();
}

class _SpotDetailsSheetState extends State<_SpotDetailsSheet> {
  MonitoringController? _monitoring;
  Future<SpotObservation>? _observation;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _monitoring = AppScope.of(context).monitoring;
    if (_requested) return;
    _requested = true;
    _observation = _loadObservation();
  }

  Future<SpotObservation> _loadObservation() async {
    final controller = _monitoring!;
    if (controller.forbidden) {
      throw const MonitoringException('Access denied.', status: 403);
    }
    if (!controller.loaded) await controller.load();
    if (controller.forbidden) {
      throw const MonitoringException('Access denied.', status: 403);
    }
    return controller.occupancyForSpot(widget.spot.id);
  }

  Future<void> _refreshObservation() async {
    setState(() {
      _observation = _monitoring!.occupancyForSpot(widget.spot.id);
    });
  }

  Future<void> _registerSensor() async {
    final now = DateTime.now();
    try {
      await _monitoring!.registerSensor(
        spotId: widget.spot.id,
        installedAt: now.subtract(const Duration(minutes: 1)),
        firstOccupancy: widget.spot.occupancy == OccupancyStatus.occupied
            ? OccupancyValue.occupied
            : OccupancyValue.available,
        occurredAt: now,
        quality: 95,
      );
      await _refreshObservation();
    } on MonitoringException catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            error.status == 409
                ? 'Sensor registration rejected (HTTP 409)'
                : 'Could not register sensor',
          ),
          content: Text(error.message),
          actions: [
            if (error.status == 409)
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  pushAdminPage<void>(context, const PlansScreen());
                },
                child: const Text('View subscription'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _deactivateSensor(MonitoringSensor sensor) async {
    try {
      await _monitoring!.deactivateSensor(sensor.sensorId);
      await _refreshObservation();
    } on MonitoringException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _showSensorHistory(MonitoringSensor sensor) async {
    try {
      final values = await Future.wait<Object>([
        _monitoring!.readings(sensor.sensorId),
        _monitoring!.healthEvents(sensor.sensorId),
      ]);
      if (!mounted) return;
      final readings = values[0] as List<OccupancyReading>;
      final health = values[1] as List<SensorHealthEvent>;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Sensor history'),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final reading in readings)
                  ListTile(
                    title: Text(reading.occupancyStatus.name),
                    subtitle: Text(
                      '${reading.occurredAt?.toLocal() ?? 'Unknown time'} · quality ${reading.quality}',
                    ),
                  ),
                for (final event in health)
                  ListTile(
                    title: Text(event.health.name),
                    subtitle: Text(event.reason),
                  ),
                if (readings.isEmpty && health.isEmpty)
                  const ListTile(title: Text('No sensor history')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on MonitoringException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _monitoring!,
    builder: (context, _) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Spot ${widget.spot.code}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${widget.zone?.name ?? 'Unassigned'} · ${widget.spot.type.label} spot',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FutureBuilder<SpotObservation>(
              future: _observation,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: ListTile(
                      leading: CircularProgressIndicator(),
                      title: Text('Loading sensor occupancy...'),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  return Card(
                    child: ListTile(
                      title: Text(
                        error is MonitoringException
                            ? error.message
                            : 'Could not load this spot occupancy.',
                      ),
                      trailing: IconButton(
                        onPressed: _monitoring!.forbidden
                            ? null
                            : _refreshObservation,
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                  );
                }
                final observation = snapshot.data!;
                final sensor = _monitoring!.sensorForSpot(widget.spot.id);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: ListTile(
                        title: Text('Occupancy: ${observation.occupancy.name}'),
                        subtitle: Text(
                          observation.reason.isEmpty
                              ? observation.occurredAt?.toLocal().toString() ??
                                    'No recent reading'
                              : observation.reason,
                        ),
                        trailing: sensor == null
                            ? null
                            : Text(sensor.status.name),
                      ),
                    ),
                    if (sensor == null)
                      FilledButton.icon(
                        onPressed: _monitoring!.forbidden
                            ? null
                            : _registerSensor,
                        icon: const Icon(Icons.sensors),
                        label: const Text('Register HTTP sensor'),
                      )
                    else ...[
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              title: Text('Sensor ${sensor.sensorId}'),
                              subtitle: Text(
                                '${sensor.protocol.name} · ${sensor.status.name}',
                              ),
                              trailing: IconButton(
                                tooltip: 'Deactivate sensor',
                                onPressed: sensor.status == SensorStatus.active
                                    ? () => _deactivateSensor(sensor)
                                    : null,
                                icon: const Icon(Icons.power_settings_new),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _showSensorHistory(sensor),
                              child: const Text('Readings and health history'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SpotStateTable(
                      spot: widget.spot,
                      guestPlate: widget.guestPlate,
                    ),
                    if (!widget.spot.canStartGuestSession ||
                        !(widget.zone?.isActive ?? false))
                      SpotNotice(
                        !widget.spot.bookable
                            ? widget.spot.availabilityReasonLabel
                            : observation.reason.isNotEmpty
                            ? observation.reason
                            : 'A sensor reading is required before this spot can be used.',
                      ),
                    if (widget.spot.canStartGuestSession &&
                        (widget.zone?.isActive ?? false)) ...[
                      const SizedBox(height: 12),
                      FilledButton(
                        key: const Key('spot-start-guest'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          pushAdminPage<void>(
                            context,
                            NewGuestSessionScreen(
                              initialSpotId: widget.spot.id,
                            ),
                          );
                        },
                        child: const Text('Start guest session here'),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
