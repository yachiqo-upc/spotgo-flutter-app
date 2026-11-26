import '../models/monitoring.dart';
import '../repositories/monitoring_repository.dart';

class MockMonitoringRepository implements MonitoringRepository {
  MockMonitoringRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    final now = _clock();
    _sensors = [
      for (final (id, spotId, sensorStatus) in const [
        ('SEN-A01', 'A-01', SensorStatus.active),
        ('SEN-A02', 'A-02', SensorStatus.active),
        ('SEN-A03', 'A-03', SensorStatus.active),
        ('SEN-A04', 'A-04', SensorStatus.inactive),
        ('SEN-B01', 'B-01', SensorStatus.active),
      ])
        MonitoringSensor(
          sensorId: id,
          tenantId: 'TENANT-DEMO',
          zoneId: 'Z-${spotId[0]}',
          spotId: spotId,
          protocol: SensorProtocol.http,
          status: sensorStatus,
          lastSeenAt: now.subtract(const Duration(minutes: 2)),
          configuration: const {},
          installedAt: now.subtract(const Duration(days: 20)),
        ),
    ];
    _readings = [
      _reading('SEN-A01', 'A-01', OccupancyValue.available, now),
      _reading('SEN-A02', 'A-02', OccupancyValue.occupied, now),
      _reading('SEN-A03', 'A-03', OccupancyValue.unavailable, now),
      _reading('SEN-B01', 'B-01', OccupancyValue.occupied, now),
    ];
    _conflicts = [
      OccupancyConflict(
        conflictId: 'CONFLICT-1',
        spotId: 'A-02',
        reservationId: 'RES-4817',
        readingId: 'READING-2',
        tenantId: 'TENANT-DEMO',
        conflictType: ConflictType.unexpectedOccupancy,
        severity: MonitoringSeverity.high,
        detectedAt: now.subtract(const Duration(minutes: 10)),
        status: MonitoringStatus.open,
      ),
      OccupancyConflict(
        conflictId: 'CONFLICT-2',
        spotId: 'B-01',
        reservationId: null,
        readingId: 'READING-4',
        tenantId: 'TENANT-DEMO',
        conflictType: ConflictType.overstay,
        severity: MonitoringSeverity.medium,
        detectedAt: now.subtract(const Duration(hours: 1)),
        status: MonitoringStatus.resolved,
      ),
    ];
    _alerts = [
      _alert('ALERT-1', 'A-02', now, conflictId: 'CONFLICT-1'),
      _alert('ALERT-2', 'A-03', now, status: MonitoringStatus.closed),
    ];
    _snapshots = [
      CapacitySnapshot(
        snapshotId: 'SNAP-1',
        tenantId: 'TENANT-DEMO',
        zoneId: 'Z-A',
        occupiedCount: 6,
        totalCount: 8,
        percentage: 75,
        observedAt: now,
      ),
    ];
    _capacityAlerts = [
      CapacityAlert(
        capacityAlertId: 'CAP-1',
        tenantId: 'TENANT-DEMO',
        zoneId: 'Z-A',
        snapshotId: 'SNAP-1',
        thresholdPercentage: 95,
        occupancyPercentage: 97,
        severity: MonitoringSeverity.high,
        status: MonitoringStatus.open,
        createdAt: now,
        acknowledgedAt: null,
        resolvedAt: null,
      ),
    ];
  }

  final DateTime Function() _clock;
  late List<MonitoringSensor> _sensors;
  late List<OccupancyReading> _readings;
  late List<OccupancyConflict> _conflicts;
  late List<OccupancyAlert> _alerts;
  late List<CapacitySnapshot> _snapshots;
  late List<CapacityAlert> _capacityAlerts;
  int _sequence = 10;

  @override
  Future<List<MonitoringSensor>> listSensors() async =>
      List.unmodifiable(_sensors);

  @override
  Future<MonitoringSensor> sensor(String sensorId) async => _sensor(sensorId);

  @override
  Future<MonitoringSensor> registerSensor({
    required String spotId,
    required DateTime installedAt,
    required OccupancyValue firstOccupancy,
    required DateTime occurredAt,
    required double quality,
  }) async {
    if (_sensors.any(
      (item) => item.spotId == spotId && item.status == SensorStatus.active,
    )) {
      throw const MonitoringException(
        'This spot already has an active sensor.',
        status: 409,
      );
    }
    final sensor = MonitoringSensor(
      sensorId: 'SEN-MOCK-${_sequence++}',
      tenantId: 'TENANT-DEMO',
      zoneId: 'Z-${spotId[0]}',
      spotId: spotId,
      protocol: SensorProtocol.http,
      status: SensorStatus.active,
      lastSeenAt: occurredAt,
      configuration: const {},
      installedAt: installedAt,
    );
    _sensors = [..._sensors, sensor];
    _readings = [
      _reading(sensor.sensorId, spotId, firstOccupancy, occurredAt),
      ..._readings,
    ];
    return sensor;
  }

  @override
  Future<MonitoringSensor> deactivateSensor(String sensorId) async {
    final old = _sensor(sensorId);
    final updated = MonitoringSensor(
      sensorId: old.sensorId,
      tenantId: old.tenantId,
      zoneId: old.zoneId,
      spotId: old.spotId,
      protocol: old.protocol,
      status: SensorStatus.inactive,
      lastSeenAt: old.lastSeenAt,
      configuration: old.configuration,
      installedAt: old.installedAt,
    );
    _sensors = [
      for (final item in _sensors) item.sensorId == sensorId ? updated : item,
    ];
    return updated;
  }

  @override
  Future<SpotObservation> occupancyForSpot(String spotId) async {
    final reading = _readings
        .where((item) => item.spotId == spotId)
        .firstOrNull;
    if (reading == null ||
        !_sensors.any(
          (item) => item.spotId == spotId && item.status == SensorStatus.active,
        )) {
      return SpotObservation(
        spotId: spotId,
        occupancy: OccupancyValue.unavailable,
        readingId: null,
        occurredAt: null,
        reason: 'NO_ACTIVE_SENSOR',
      );
    }
    return SpotObservation(
      spotId: spotId,
      occupancy: reading.occupancyStatus,
      readingId: reading.readingId,
      occurredAt: reading.occurredAt,
      reason: '',
    );
  }

  @override
  Future<List<OccupancyReading>> readings(String sensorId) async {
    _sensor(sensorId);
    return _readings.where((item) => item.sensorId == sensorId).toList();
  }

  @override
  Future<OccupancyReading> addReading({
    required String sensorId,
    required OccupancyValue occupancy,
    required DateTime occurredAt,
    required double quality,
  }) async {
    final sensor = _sensor(sensorId);
    final reading = OccupancyReading(
      readingId: 'READING-${_sequence++}',
      sensorId: sensorId,
      spotId: sensor.spotId,
      occupancyStatus: occupancy,
      occurredAt: occurredAt,
      receivedAt: _clock(),
      quality: quality,
      payloadHash: '',
    );
    _readings = [reading, ..._readings];
    return reading;
  }

  @override
  Future<List<SensorHealthEvent>> healthEvents(String sensorId) async {
    _sensor(sensorId);
    return const [];
  }

  @override
  Future<SensorHealthEvent> healthEvent(String healthEventId) async =>
      SensorHealthEvent(
        healthEventId: healthEventId,
        sensorId: 'SEN-A01',
        health: SensorHealth.healthy,
        reason: 'Sensor healthy',
        observedAt: _clock(),
        recoveredAt: null,
      );

  @override
  Future<SensorHealthEvent> addHealthEvent({
    required String sensorId,
    required SensorHealth health,
    required String reason,
  }) async => SensorHealthEvent(
    healthEventId: 'HEALTH-${_sequence++}',
    sensorId: sensorId,
    health: health,
    reason: reason,
    observedAt: _clock(),
    recoveredAt: null,
  );

  @override
  Future<SensorHealthEvent> recoverHealthEvent(String healthEventId) async =>
      SensorHealthEvent(
        healthEventId: healthEventId,
        sensorId: 'SEN-A01',
        health: SensorHealth.healthy,
        reason: 'Recovered',
        observedAt: _clock(),
        recoveredAt: _clock(),
      );

  @override
  Future<List<OccupancyConflict>> conflicts() async =>
      List.unmodifiable(_conflicts);

  @override
  Future<OccupancyConflict> conflict(String conflictId) async =>
      _conflict(conflictId);

  @override
  Future<OccupancyConflict> acknowledgeConflict(String conflictId) async =>
      _updateConflict(conflictId, MonitoringStatus.acknowledged);

  @override
  Future<OccupancyConflict> resolveConflict(String conflictId) async =>
      _updateConflict(conflictId, MonitoringStatus.resolved);

  @override
  Future<List<OccupancyAlert>> alerts() async => List.unmodifiable(_alerts);

  @override
  Future<OccupancyAlert> acknowledgeAlert(String alertId) async =>
      _updateAlert(alertId, MonitoringStatus.acknowledged);

  @override
  Future<OccupancyAlert> closeAlert({
    required String alertId,
    required ResolutionClassification classification,
    required String action,
  }) async {
    final old = _alertById(alertId);
    if (old.conflictId != null &&
        _conflict(old.conflictId!).status != MonitoringStatus.resolved) {
      throw const MonitoringException(
        'Resolve the linked conflict before closing this alert.',
        status: 409,
      );
    }
    final updated = OccupancyAlert(
      alertId: old.alertId,
      tenantId: old.tenantId,
      healthEventId: old.healthEventId,
      conflictId: old.conflictId,
      spotId: old.spotId,
      alertType: old.alertType,
      severity: old.severity,
      evidenceRef: old.evidenceRef,
      createdAt: old.createdAt,
      acknowledgedAt: old.acknowledgedAt,
      closedAt: _clock(),
      resolutionClassification: classification,
      resolutionAction: action,
      status: MonitoringStatus.closed,
    );
    _alerts = [
      for (final item in _alerts) item.alertId == alertId ? updated : item,
    ];
    return updated;
  }

  @override
  Future<void> uploadEvidence({
    required String alertId,
    required List<int> bytes,
    required String contentType,
  }) async {
    _alertById(alertId);
  }

  @override
  Future<List<int>> evidence(String alertId) async {
    _alertById(alertId);
    throw const MonitoringException(
      'No evidence has been uploaded.',
      status: 404,
    );
  }

  @override
  Future<List<CapacitySnapshot>> capacitySnapshots() async =>
      List.unmodifiable(_snapshots);

  @override
  Future<CapacitySnapshot> createCapacitySnapshot({String? zoneId}) async {
    final snapshot = CapacitySnapshot(
      snapshotId: 'SNAP-${_sequence++}',
      tenantId: 'TENANT-DEMO',
      zoneId: zoneId,
      occupiedCount: 6,
      totalCount: 8,
      percentage: 75,
      observedAt: _clock(),
    );
    _snapshots = [snapshot, ..._snapshots];
    return snapshot;
  }

  @override
  Future<List<CapacityAlert>> capacityAlerts() async =>
      List.unmodifiable(_capacityAlerts);

  @override
  Future<CapacityAlert> acknowledgeCapacityAlert(String alertId) async {
    final old = _capacityAlerts
        .where((item) => item.capacityAlertId == alertId)
        .firstOrNull;
    if (old == null) {
      throw const MonitoringException('Capacity alert not found.');
    }
    final updated = CapacityAlert(
      capacityAlertId: old.capacityAlertId,
      tenantId: old.tenantId,
      zoneId: old.zoneId,
      snapshotId: old.snapshotId,
      thresholdPercentage: old.thresholdPercentage,
      occupancyPercentage: old.occupancyPercentage,
      severity: old.severity,
      status: MonitoringStatus.acknowledged,
      createdAt: old.createdAt,
      acknowledgedAt: _clock(),
      resolvedAt: old.resolvedAt,
    );
    _capacityAlerts = [
      for (final item in _capacityAlerts)
        item.capacityAlertId == alertId ? updated : item,
    ];
    return updated;
  }

  @override
  Future<List<OccupancyReport>> reports() async => const [];

  @override
  Future<OccupancyReport> createReport({
    required String zoneId,
    required DateTime intervalStart,
    required DateTime intervalEnd,
  }) async => OccupancyReport(
    reportId: 'REPORT-${_sequence++}',
    tenantId: 'TENANT-DEMO',
    zoneId: zoneId,
    intervalStart: intervalStart,
    intervalEnd: intervalEnd,
    totals: const {'averageOccupancy': 68, 'peakOccupancy': 91, 'overstays': 0},
    generatedAt: _clock(),
    status: OccupancyReportStatus.generated,
  );

  @override
  Future<ParkingMapLayout?> getPublishedMap(String zoneId) async => null;

  MonitoringSensor _sensor(String id) =>
      _sensors.where((item) => item.sensorId == id).firstOrNull ??
      (throw const MonitoringException('Sensor not found.', status: 404));

  OccupancyConflict _conflict(String id) =>
      _conflicts.where((item) => item.conflictId == id).firstOrNull ??
      (throw const MonitoringException('Conflict not found.', status: 404));

  OccupancyConflict _updateConflict(String id, MonitoringStatus status) {
    final old = _conflict(id);
    final updated = OccupancyConflict(
      conflictId: old.conflictId,
      spotId: old.spotId,
      reservationId: old.reservationId,
      readingId: old.readingId,
      tenantId: old.tenantId,
      conflictType: old.conflictType,
      severity: old.severity,
      detectedAt: old.detectedAt,
      status: status,
    );
    _conflicts = [
      for (final item in _conflicts) item.conflictId == id ? updated : item,
    ];
    return updated;
  }

  OccupancyAlert _alertById(String id) =>
      _alerts.where((item) => item.alertId == id).firstOrNull ??
      (throw const MonitoringException('Alert not found.', status: 404));

  OccupancyAlert _updateAlert(String id, MonitoringStatus status) {
    final old = _alertById(id);
    final updated = OccupancyAlert(
      alertId: old.alertId,
      tenantId: old.tenantId,
      healthEventId: old.healthEventId,
      conflictId: old.conflictId,
      spotId: old.spotId,
      alertType: old.alertType,
      severity: old.severity,
      evidenceRef: old.evidenceRef,
      createdAt: old.createdAt,
      acknowledgedAt: status == MonitoringStatus.acknowledged
          ? _clock()
          : old.acknowledgedAt,
      closedAt: old.closedAt,
      resolutionClassification: old.resolutionClassification,
      resolutionAction: old.resolutionAction,
      status: status,
    );
    _alerts = [for (final item in _alerts) item.alertId == id ? updated : item];
    return updated;
  }

  OccupancyReading _reading(
    String sensorId,
    String spotId,
    OccupancyValue state,
    DateTime at,
  ) => OccupancyReading(
    readingId: 'READING-${_sequence++}',
    sensorId: sensorId,
    spotId: spotId,
    occupancyStatus: state,
    occurredAt: at,
    receivedAt: at,
    quality: state == OccupancyValue.unavailable ? 0 : 96.5,
    payloadHash: '',
  );

  OccupancyAlert _alert(
    String id,
    String spotId,
    DateTime now, {
    String? conflictId,
    MonitoringStatus status = MonitoringStatus.open,
  }) => OccupancyAlert(
    alertId: id,
    tenantId: 'TENANT-DEMO',
    healthEventId: null,
    conflictId: conflictId,
    spotId: spotId,
    alertType: AlertType.occupancyConflict,
    severity: MonitoringSeverity.high,
    evidenceRef: null,
    createdAt: now.subtract(const Duration(minutes: 10)),
    acknowledgedAt: null,
    closedAt: status == MonitoringStatus.closed ? now : null,
    resolutionClassification: ResolutionClassification.unknown,
    resolutionAction: null,
    status: status,
  );
}
