import '../../domain/parking_rules.dart';
import '../models/guest_session.dart';
import '../models/operational_alert.dart';
import '../models/parking_snapshot.dart';
import '../models/parking_spot.dart';
import '../models/parking_zone.dart';
import '../repositories/parking_repository.dart';
import 'mock_seed.dart';

/// In-memory implementation used while the SpotGo backend is unavailable.
/// It applies the same business rules a server would enforce, but all data
/// is local sample data and is reset when the app restarts.
class MockParkingRepository implements ParkingRepository {
  MockParkingRepository({
    DateTime Function()? clock,
    this.latency = const Duration(milliseconds: 400),
    this.failFirstFetch = false,
  }) : _clock = clock ?? DateTime.now {
    final seed = MockSeed.build(_clock());
    _zones = seed.zones;
    _spots = seed.spots;
    _alerts = seed.alerts;
    _sessions = seed.sessions;
  }

  final DateTime Function() _clock;
  final Duration latency;
  bool failFirstFetch;

  late List<ParkingZone> _zones;
  late List<ParkingSpot> _spots;
  late List<OperationalAlert> _alerts;
  late List<GuestSession> _sessions;
  final List<AuditEntry> _audit = [];
  int _sequence = 1050;

  Future<void> _delay() => Future<void>.delayed(latency);

  @override
  Future<ParkingSnapshot> fetchSnapshot() async {
    await _delay();
    if (failFirstFetch) {
      failFirstFetch = false;
      throw Exception('Service temporarily unavailable');
    }
    return ParkingSnapshot(
      facilityName: MockSeed.facilityName,
      district: MockSeed.district,
      zones: List.unmodifiable(_zones),
      spots: List.unmodifiable(_spots),
      alerts: List.unmodifiable(
        [..._alerts]..sort((a, b) => b.detectedAt.compareTo(a.detectedAt)),
      ),
      guestSessions: List.unmodifiable(
        [..._sessions]..sort((a, b) => b.entryAt.compareTo(a.entryAt)),
      ),
      outstandingBalances: MockSeed.outstandingBalances,
      audit: List.unmodifiable(_audit.reversed),
      updatedAt: _clock(),
    );
  }

  @override
  Future<ParkingZone> saveZone(ParkingZone zone, {required String actor}) async {
    await _delay();
    if (zone.name.trim().length < 3) {
      throw const ParkingRuleException('Zone name is required');
    }
    final hoursError = ParkingRules.validateOperatingHours(
      zone.opensAtMinutes,
      zone.closesAtMinutes,
    );
    if (hoursError != null) throw ParkingRuleException(hoursError);
    if (zone.ratePerHour <= 0) {
      throw const ParkingRuleException('Rate per hour must be positive');
    }
    if (zone.billingFractionMinutes <= 0) {
      throw const ParkingRuleException('Billing fraction must be positive');
    }
    if (zone.spotIds.isEmpty) {
      throw const ParkingRuleException('Assign at least one spot');
    }
    if (zone.allowedTypes.isEmpty) {
      throw const ParkingRuleException('Select at least one spot type');
    }

    final isNew = zone.id.isEmpty;
    final conflicts = ParkingRules.conflictingSpots(
      zoneId: isNew ? null : zone.id,
      selectedSpotIds: zone.spotIds,
      zones: _zones,
    );
    if (conflicts.isNotEmpty) {
      throw ParkingRuleException(
        'Spots already assigned to another zone: ${_codes(conflicts)}. '
        'Resolve the assignment first.',
      );
    }
    for (final spotId in zone.spotIds) {
      final spot = _spot(spotId);
      if (!zone.allowedTypes.contains(spot.type)) {
        throw ParkingRuleException(
          'Spot ${spot.code} is ${spot.type.label}, which is not an allowed '
          'type for this zone.',
        );
      }
    }

    final previous = isNew ? null : _zones.firstWhere((z) => z.id == zone.id);
    final removed = previous?.spotIds.where((id) => !zone.spotIds.contains(id));
    for (final spotId in removed ?? const <String>[]) {
      if (_spot(spotId).guestSessionId != null) {
        throw ParkingRuleException(
          'Spot ${_spot(spotId).code} has an active guest session and cannot '
          'be removed from the zone.',
        );
      }
    }

    final saved = isNew
        ? ParkingZone(
            id: 'Z-${_sequence++}',
            name: zone.name.trim(),
            address: zone.address.trim(),
            district: zone.district.trim(),
            opensAtMinutes: zone.opensAtMinutes,
            closesAtMinutes: zone.closesAtMinutes,
            ratePerHour: zone.ratePerHour,
            billingFractionMinutes: zone.billingFractionMinutes,
            status: zone.status,
            allowedTypes: Set.unmodifiable(zone.allowedTypes),
            spotIds: List.unmodifiable(zone.spotIds),
          )
        : zone;

    _zones = [
      for (final z in _zones)
        if (z.id == saved.id) saved else z,
      if (isNew) saved,
    ];
    _spots = [
      for (final s in _spots)
        if (saved.spotIds.contains(s.id))
          s.copyWith(zoneId: saved.id)
        else if (s.zoneId == saved.id)
          s.copyWith(zoneId: '')
        else
          s,
    ];
    _log(
      actor,
      isNew ? 'Created zone ${saved.name}' : 'Updated zone ${saved.name}',
      previous == null ? '-' : _zoneSummary(previous),
      _zoneSummary(saved),
    );
    return saved;
  }

  @override
  Future<GuestSession> startGuestSession(
    GuestSessionDraft draft, {
    required String actor,
  }) async {
    await _delay();
    final plateError = ParkingRules.validatePlate(draft.plate);
    if (plateError != null) throw ParkingRuleException(plateError);
    if (draft.expectedDuration <= Duration.zero) {
      throw const ParkingRuleException('Select the expected duration');
    }
    final plate = ParkingRules.normalizePlate(draft.plate);
    if (_sessions.any((s) => !s.isClosed && s.plate == plate)) {
      throw ParkingRuleException('$plate already has an open guest session.');
    }
    final spot = _spot(draft.spotId);
    final zone = _zones.where((z) => z.id == spot.zoneId).firstOrNull;
    if (zone == null) {
      throw ParkingRuleException('Spot ${spot.code} is not assigned to a zone.');
    }
    ParkingRules.ensureGuestSpotAvailable(spot, zone);

    final session = GuestSession(
      id: 'GP-${_sequence++}',
      plate: plate,
      vehicleType: draft.vehicleType,
      color: (draft.color?.trim().isEmpty ?? true) ? null : draft.color!.trim(),
      zoneId: zone.id,
      spotId: spot.id,
      spotCode: spot.code,
      entryAt: _clock(),
      expectedDuration: draft.expectedDuration,
      status: GuestSessionStatus.open,
    );
    _sessions = [..._sessions, session];
    _replaceSpot(spot.copyWith(guestSessionId: session.id));
    _log(
      actor,
      'Started guest session ${session.id}',
      'Spot ${spot.code} ${spot.availability.label}',
      '$plate at ${spot.code}',
    );
    _evaluateHighOccupancy();
    return session;
  }

  @override
  Future<GuestSession> registerGuestExit(
    String sessionId, {
    required String actor,
  }) async {
    await _delay();
    final session = _session(sessionId);
    if (session.isClosed) {
      throw const ParkingRuleException('The session is already closed.');
    }
    if (session.exitRegistered) {
      throw const ParkingRuleException('The exit was already registered.');
    }
    final zone = _zones.firstWhere((z) => z.id == session.zoneId);
    final exitAt = _clock();
    final updated = session.copyWith(
      exitAt: exitAt,
      amount: ParkingRules.guestAmount(
        entryAt: session.entryAt,
        exitAt: exitAt,
        ratePerHour: zone.ratePerHour,
        billingFractionMinutes: zone.billingFractionMinutes,
      ),
    );
    _replaceSession(updated);
    _log(actor, 'Registered exit for ${session.id}', 'Open', 'Exit recorded');
    return updated;
  }

  @override
  Future<GuestSession> confirmGuestPayment(
    String sessionId, {
    required PhysicalPaymentMethod method,
    String? reference,
    required String actor,
  }) async {
    await _delay();
    final session = _session(sessionId);
    if (session.isClosed) {
      throw const ParkingRuleException('The session is already closed.');
    }
    if (!session.exitRegistered || session.amount == null) {
      throw const ParkingRuleException(
        'Register the exit before confirming the payment.',
      );
    }
    final cleanReference = reference?.trim();
    if (cleanReference != null &&
        RegExp(r'\d{12,19}').hasMatch(cleanReference.replaceAll(' ', ''))) {
      throw const ParkingRuleException(
        'Do not enter card numbers. Use the receipt or voucher number only.',
      );
    }
    final updated = session.copyWith(
      paymentMethod: method,
      paymentConfirmed: true,
      paymentReference: (cleanReference?.isEmpty ?? true)
          ? null
          : cleanReference,
      status: GuestSessionStatus.closed,
    );
    _replaceSession(updated);
    final spot = _spot(session.spotId);
    _replaceSpot(
      spot.copyWith(
        clearGuestSession: true,
        occupancy: spot.sensorReliable ? OccupancyStatus.available : null,
        lastReadingAt: _clock(),
      ),
    );
    _log(
      actor,
      'Closed guest session ${session.id}',
      'Open · exit recorded',
      'Closed · ${method.label} confirmed',
    );
    return updated;
  }

  @override
  Future<OperationalAlert> updateAlert(
    String alertId, {
    required String classification,
    required String action,
    required bool actionCompleted,
    required String actor,
  }) async {
    await _delay();
    final alert = _alerts.firstWhere(
      (a) => a.id == alertId,
      orElse: () => throw const ParkingRuleException('Alert not found'),
    );
    if (!alert.isPending) {
      throw const ParkingRuleException('This alert is already resolved.');
    }
    final error = ParkingRules.validateAlertResolution(
      classification: classification,
      action: action,
      actionCompleted: true,
    );
    if (error != null) throw ParkingRuleException(error);

    final status = actionCompleted
        ? AlertStatus.resolved
        : AlertStatus.monitoring;
    final updated = alert.copyWith(
      status: status,
      classification: classification,
      actionTaken: action.trim(),
      history: [
        ...alert.history,
        AlertEvent(
          at: _clock(),
          actor: actor,
          description: actionCompleted
              ? 'Resolved as "$classification": ${action.trim()}'
              : 'Monitoring as "$classification": ${action.trim()}',
        ),
      ],
    );
    _alerts = [
      for (final a in _alerts)
        if (a.id == alertId) updated else a,
    ];
    _log(actor, 'Updated alert ${alert.id}', alert.status.label, status.label);
    return updated;
  }

  void _evaluateHighOccupancy() {
    final alreadyOpen = _alerts.any(
      (a) => a.type == AlertType.highOccupancy && a.isPending,
    );
    if (alreadyOpen || !ParkingRules.isHighOccupancy(_spots)) return;
    final ratio = ParkingRules.occupancyRatio(_spots);
    final now = _clock();
    _alerts = [
      ..._alerts,
      OperationalAlert(
        id: 'AL-${_sequence++}',
        type: AlertType.highOccupancy,
        severity: AlertSeverity.high,
        description:
            '${MockSeed.facilityName} · Occupancy at '
            '${(ratio * 100).round()}% of operational spots.',
        zoneId: '',
        source: 'Occupancy monitor',
        detectedAt: now,
        status: AlertStatus.open,
        history: [
          AlertEvent(
            at: now,
            actor: 'System',
            description: 'Occupancy exceeded 95% of operational spots',
          ),
        ],
      ),
    ];
  }

  ParkingSpot _spot(String id) => _spots.firstWhere(
    (s) => s.id == id,
    orElse: () => throw ParkingRuleException('Spot $id not found'),
  );

  GuestSession _session(String id) => _sessions.firstWhere(
    (s) => s.id == id,
    orElse: () => throw ParkingRuleException('Session $id not found'),
  );

  void _replaceSpot(ParkingSpot spot) {
    _spots = [
      for (final s in _spots)
        if (s.id == spot.id) spot else s,
    ];
  }

  void _replaceSession(GuestSession session) {
    _sessions = [
      for (final s in _sessions)
        if (s.id == session.id) session else s,
    ];
  }

  String _codes(List<String> spotIds) =>
      spotIds.map((id) => _spot(id).code).join(', ');

  String _zoneSummary(ParkingZone zone) =>
      '${zone.name}, ${zone.totalSpots} spots, '
      'S/ ${zone.ratePerHour.toStringAsFixed(2)}/h, '
      '${zone.billingFractionMinutes} min, ${zone.status.label}';

  void _log(String actor, String action, String before, String after) {
    _audit.add(
      AuditEntry(
        at: _clock(),
        actor: actor,
        action: action,
        before: before,
        after: after,
      ),
    );
  }
}
