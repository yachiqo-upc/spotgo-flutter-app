import '../../domain/parking_rules.dart';
import '../models/guest_session.dart';
import '../models/operational_alert.dart';
import '../models/parking_snapshot.dart';
import '../models/parking_spot.dart';
import '../models/parking_zone.dart';
import '../repositories/parking_repository.dart';
import 'spotgo_api.dart';

class RemoteParkingRepository implements ParkingRepository {
  RemoteParkingRepository(this.api);
  final SpotGoApi api;

  final _zones = <String, Json>{};
  final _spots = <String, ParkingSpot>{};
  final _guests = <String, GuestSession>{};
  final _alerts = <String, OperationalAlert>{};

  Json get _tenant =>
      api.tenant ??
      (throw const ParkingRuleException(
        'Your session has ended. Sign in again.',
      ));

  @override
  Future<ParkingSnapshot> fetchSnapshot() async {
    final tenant = _tenant;
    final tenantQuery = {'tenantId': tenant['tenantId'] as String};
    final groups = await Future.wait([
      api.list('/parking-zones', tenantQuery),
      api.list('/guest-parking-sessions'),
      api.list('/reservations'),
      api.list('/occupancy-sensors', tenantQuery),
      api.list('/occupancy-alerts', tenantQuery),
      api.list('/capacity-alerts', tenantQuery),
      api.list('/occupancy-conflicts', tenantQuery),
      api.list('/outstanding-balances'),
    ]);
    final now = DateTime.now().toUtc();
    final zoneRows = groups[0];
    final guestRows = groups[1];
    final reservations = groups[2];
    final sensors = _index(groups[3], 'spotId');
    final conflicts = _index(groups[6], 'conflictId');
    final openGuests = _index(
      guestRows.where((row) => row['status'] == 'OPEN'),
      'spotId',
    );
    final activeReservations = _index(
      reservations.where((row) => row['status'] == 'ACTIVE'),
      'spotId',
    );
    final currentReservations = _index(
      reservations.where((row) {
        final start = _date(row['startAt']);
        final end = _date(row['endAt']);
        return row['status'] == 'RESERVED' &&
            start != null &&
            !start.isAfter(now) &&
            end != null &&
            end.isAfter(now);
      }),
      'spotId',
    );

    final loadedSpots = await Future.wait(
      zoneRows.map((zone) async {
        final zoneId = zone['zoneId'] as String;
        final results = await Future.wait([
          api.list('/parking-spots', {'zoneId': zoneId}),
          api.list('/parking-spots/availability', {
            'zoneId': zoneId,
            'startAt': now
                .subtract(const Duration(seconds: 1))
                .toIso8601String(),
            'endAt': now.add(const Duration(minutes: 1)).toIso8601String(),
          }),
        ]);
        final availability = _index(results[1], 'spotId');
        return results[0].map((row) {
          final id = row['spotId'] as String;
          final state = availability[id];
          final sensor = sensors[id];
          final occupancy = switch (state?['physicalOccupancy']) {
            'AVAILABLE' => OccupancyStatus.available,
            'OCCUPIED' => OccupancyStatus.occupied,
            _ => OccupancyStatus.unavailable,
          };
          final reservation = activeReservations[id] ?? currentReservations[id];
          return ParkingSpot(
            id: id,
            code: row['code'] as String,
            zoneId: zoneId,
            type: _spotType(row),
            occupancy:
                row['operationalStatus'] == 'ACTIVE' &&
                    zone['status'] == 'ACTIVE'
                ? occupancy
                : OccupancyStatus.unavailable,
            reservation: activeReservations.containsKey(id)
                ? ReservationState.active
                : reservation != null ||
                      state?['reason'] == 'RESERVATION_OR_OPEN_STAY' &&
                          !openGuests.containsKey(id)
                ? ReservationState.reserved
                : ReservationState.none,
            reservationCode: reservation?['reservationId'] as String?,
            sensorId: sensor?['sensorId'] as String? ?? '',
            sensorHealth: occupancy == OccupancyStatus.unavailable
                ? SensorHealth.failed
                : SensorHealth.healthy,
            lastReadingAt:
                _date(sensor?['lastSeenAt']) ??
                DateTime.fromMillisecondsSinceEpoch(0),
            guestSessionId: openGuests[id]?['guestSessionId'] as String?,
          );
        }).toList();
      }),
    );
    if (!identical(tenant, api.tenant)) {
      throw const ParkingRuleException(
        'Your session has ended. Sign in again.',
      );
    }
    final spots = loadedSpots.expand((items) => items).toList();
    _spots
      ..clear()
      ..addEntries(spots.map((spot) => MapEntry(spot.id, spot)));
    _zones
      ..clear()
      ..addAll(_index(zoneRows, 'zoneId'));
    final zones = zoneRows.map((row) => _zone(row, tenant)).toList();
    final guests = guestRows.map(_guest).toList();
    final alerts = [
      for (final row in groups[4])
        _alert(row, conflict: conflicts[row['conflictId']]),
      for (final row in groups[5]) _alert(row, capacity: true),
    ];
    _guests
      ..clear()
      ..addEntries(guests.map((item) => MapEntry(item.id, item)));
    _alerts
      ..clear()
      ..addEntries(alerts.map((item) => MapEntry(item.id, item)));
    return ParkingSnapshot(
      facilityName: tenant['name'] as String,
      district: _district(tenant['address']),
      zones: zones,
      spots: spots,
      alerts: alerts,
      guestSessions: guests,
      outstandingBalances: groups[7]
          .where((row) => row['status'] == 'OPEN')
          .length,
      audit: const [],
      updatedAt: now,
    );
  }

  @override
  Future<ParkingZone> saveZone(
    ParkingZone zone, {
    required String actor,
  }) async {
    final tenant = _tenant;
    final existing = _zones[zone.id];
    final location = {
      ..._json(existing?['location']),
      'address': zone.address,
      'district': zone.district,
      'opensAtMinutes': zone.opensAtMinutes,
      'closesAtMinutes': zone.closesAtMinutes,
    };
    final body = <String, dynamic>{
      'name': zone.name,
      'location': location,
      'colorCode': existing?['colorCode'] ?? '#2563EB',
      'status': zone.isActive ? 'ACTIVE' : 'INACTIVE',
      'allowedProfileTypes': [
        if (zone.authorizedProfiles.contains(AccessProfile.standard)) 'PRIVATE',
        if (zone.authorizedProfiles.contains(AccessProfile.tenantStaff))
          'EMPLOYEE',
        if (zone.authorizedProfiles.contains(AccessProfile.taxi)) 'TAXI',
      ],
    };
    final row = existing == null
        ? await api.request(
            '/parking-zones',
            method: 'POST',
            body: body,
            query: {'tenantId': tenant['tenantId'] as String},
          ) as Json
        : await api.object(
            '/parking-zones/${zone.id}',
            method: 'PUT',
            body: body,
          );
    return _zone(row, tenant);
  }

  @override
  Future<GuestSession> startGuestSession(
    GuestSessionDraft draft, {
    required String actor,
  }) async => _guest(
    await api.object(
      '/guest-parking-sessions',
      method: 'POST',
      body: {
        'spotId': draft.spotId,
        'manualPlate': draft.plate.trim(),
        'physicalPaymentMethod':
            draft.paymentMethod == PhysicalPaymentMethod.cash ? 'CASH' : 'POS',
      },
    ),
  );

  @override
  Future<GuestSession> registerGuestExit(
    String sessionId, {
    required String actor,
  }) async => _guest(
    await api.object(
      '/guest-parking-sessions/$sessionId/exit',
      method: 'POST',
      body: {'physicalPaymentConfirmed': false},
    ),
  );

  @override
  Future<GuestSession> confirmGuestPayment(
    String sessionId, {
    required PhysicalPaymentMethod method,
    String? reference,
    required String actor,
  }) async {
    final recordedMethod = _guests[sessionId]?.paymentMethod;
    if (recordedMethod != null && method != recordedMethod) {
      throw ParkingRuleException(
        'Confirm the method recorded at entry: ${recordedMethod.label}.',
      );
    }
    return _guest(
      await api.object(
        '/guest-parking-sessions/$sessionId/confirm-payment',
        method: 'POST',
        body: {},
      ),
    );
  }

  @override
  Future<OperationalAlert> updateAlert(
    String alertId, {
    required String classification,
    required String action,
    required bool actionCompleted,
    required String actor,
  }) async {
    final existing = _alerts[alertId];
    if (existing == null) {
      throw const ParkingRuleException(
        'Alert not found. Refresh and try again.',
      );
    }
    final capacity = existing.type == AlertType.highOccupancy;
    if (capacity && actionCompleted) {
      throw const ParkingRuleException(
        'Capacity alerts close automatically when occupancy falls below the threshold.',
      );
    }
    final path = capacity ? '/capacity-alerts' : '/occupancy-alerts';
    if (!actionCompleted && existing.status == AlertStatus.monitoring) {
      return existing;
    }
    final row = await api.object(
      '$path/$alertId/${actionCompleted ? 'close' : 'acknowledge'}',
      method: 'POST',
      body: actionCompleted
          ? {
              'resolutionClassification': switch (classification) {
                'Unauthorized vehicle' => 'UNAUTHORIZED_OCCUPANCY',
                'Spot reassigned' => 'RESERVATION_REASSIGNED',
                'Sensor false positive' => 'FALSE_POSITIVE',
                _ => 'OTHER',
              },
              'resolutionAction': action.trim(),
            }
          : {},
    );
    return _alert(row, capacity: capacity, previousType: existing.type);
  }

  ParkingZone _zone(Json row, Json tenant) {
    final id = row['zoneId'] as String;
    final location = _json(row['location']);
    final tariff = _json(_json(tenant['rules'])['tariff_rules']);
    final fraction = (tariff['period_minutes'] as num?)?.toInt() ?? 60;
    final spots = _spots.values.where((spot) => spot.zoneId == id);
    final profiles = row['allowedProfileTypes'] as List<dynamic>? ?? const [];
    return ParkingZone(
      id: id,
      name: row['name'] as String,
      address:
          location['address'] as String? ?? tenant['address'] as String? ?? '',
      district: location['district'] as String? ?? _district(tenant['address']),
      opensAtMinutes: location['opensAtMinutes'] as int? ?? 0,
      closesAtMinutes: location['closesAtMinutes'] as int? ?? 1439,
      ratePerHour:
          ((tariff['price_per_period'] as num?)?.toDouble() ?? 0) *
          60 /
          (fraction > 0 ? fraction : 60),
      billingFractionMinutes: fraction,
      status: row['status'] == 'ACTIVE'
          ? ZoneStatus.active
          : ZoneStatus.unavailable,
      allowedTypes: spots.map((spot) => spot.type).toSet(),
      authorizedProfiles: {
        if (profiles.contains('PRIVATE')) AccessProfile.standard,
        if (profiles.contains('EMPLOYEE')) AccessProfile.tenantStaff,
        if (profiles.contains('TAXI')) AccessProfile.taxi,
      },
      spotIds: spots.map((spot) => spot.id).toList(),
    );
  }

  GuestSession _guest(Json row) {
    final spotId = row['spotId'] as String;
    return GuestSession(
      id: row['guestSessionId'] as String,
      plate: row['manualPlate'] as String,
      vehicleType: null,
      zoneId: row['zoneId'] as String,
      spotId: spotId,
      spotCode: _spots[spotId]?.code ?? spotId,
      entryAt: DateTime.parse(row['entryAt'] as String),
      expectedDuration: Duration.zero,
      exitAt: _date(row['exitAt']),
      amount: row['exitAt'] == null
          ? null
          : (row['calculatedAmount'] as num?)?.toDouble(),
      paymentMethod: row['physicalPaymentMethod'] == 'POS'
          ? PhysicalPaymentMethod.externalPos
          : PhysicalPaymentMethod.cash,
      paymentConfirmed: row['physicalPaymentConfirmed'] == true,
      status: switch (row['status']) {
        'CLOSED' => GuestSessionStatus.closed,
        'PENDING_REVIEW' => GuestSessionStatus.pendingReview,
        _ => GuestSessionStatus.open,
      },
    );
  }

  OperationalAlert _alert(
    Json row, {
    bool capacity = false,
    Json? conflict,
    AlertType? previousType,
  }) {
    final spot = _spots[row['spotId']];
    final type =
        previousType ??
        (capacity
            ? AlertType.highOccupancy
            : switch (conflict?['conflictType']) {
                'OVERSTAY' => AlertType.overstay,
                'UNEXPECTED_OCCUPANCY' => AlertType.unauthorizedOccupancy,
                'SPACE_NOT_AVAILABLE' ||
                'EXPECTED_OCCUPANCY_MISSING' => AlertType.reservationConflict,
                _ =>
                  row['alertType'] == 'SENSOR_FAILURE'
                      ? AlertType.sensorOffline
                      : AlertType.reservationConflict,
              });
    final createdAt = DateTime.parse(row['createdAt'] as String);
    final acknowledged = _date(row['acknowledgedAt']);
    final closed = _date(row['closedAt'] ?? row['resolvedAt']);
    return OperationalAlert(
      id: row[capacity ? 'capacityAlertId' : 'alertId'] as String,
      type: type,
      severity: switch (row['severity']) {
        'HIGH' || 'CRITICAL' => AlertSeverity.high,
        'MEDIUM' => AlertSeverity.medium,
        _ => AlertSeverity.info,
      },
      description: capacity
          ? 'Occupancy: ${row['occupancyPercentage']}%'
          : type.label,
      zoneId: (row['zoneId'] as String?) ?? spot?.zoneId ?? '',
      spotCode: spot?.code,
      source:
          (row['healthEventId'] ?? row['conflictId'] ?? row['snapshotId'] ?? '')
              as String,
      detectedAt: createdAt,
      status: switch (row['status']) {
        'CLOSED' || 'RESOLVED' => AlertStatus.resolved,
        'ACKNOWLEDGED' => AlertStatus.monitoring,
        _ => AlertStatus.open,
      },
      classification: row['resolutionClassification'] as String?,
      actionTaken: row['resolutionAction'] as String?,
      history: [
        AlertEvent(
          at: createdAt,
          actor: 'SpotGo',
          description: 'Alert created',
        ),
        if (acknowledged != null)
          AlertEvent(
            at: acknowledged,
            actor: 'SpotGo',
            description: 'Alert acknowledged',
          ),
        if (closed != null)
          AlertEvent(
            at: closed,
            actor: 'SpotGo',
            description: 'Alert resolved',
          ),
      ],
    );
  }
}

Map<String, Json> _index(Iterable<Json> rows, String key) => {
  for (final row in rows)
    if (row[key] is String) row[key] as String: row,
};
Json _json(Object? value) => value is Json ? value : const {};
DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
String _district(Object? address) =>
    address is String ? address.split(',').last.trim() : '';

SpotType _spotType(Json row) {
  final features = _json(row['features']);
  if (features['accessible'] == true || row['spotType'] == 'ACCESSIBLE') {
    return SpotType.accessible;
  }
  if (features['ev_charger'] == true || row['spotType'] == 'EV') {
    return SpotType.ev;
  }
  if (features['covered'] == true || row['spotType'] == 'COVERED') {
    return SpotType.covered;
  }
  return SpotType.standard;
}
