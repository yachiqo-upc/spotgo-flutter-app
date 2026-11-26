typedef MonitoringJson = Map<String, dynamic>;

enum SensorProtocol {
  http,
  mqtt,
  unknown;

  static SensorProtocol parse(Object? value) => switch (value) {
    'HTTP' => SensorProtocol.http,
    'MQTT' => SensorProtocol.mqtt,
    _ => SensorProtocol.unknown,
  };
}

enum SensorStatus {
  active,
  inactive,
  unknown;

  static SensorStatus parse(Object? value) => switch (value) {
    'ACTIVE' => SensorStatus.active,
    'INACTIVE' => SensorStatus.inactive,
    _ => SensorStatus.unknown,
  };
}

enum OccupancyValue {
  available,
  occupied,
  unavailable,
  unknown;

  static OccupancyValue parse(Object? value) => switch (value) {
    'AVAILABLE' => OccupancyValue.available,
    'OCCUPIED' => OccupancyValue.occupied,
    'UNAVAILABLE' => OccupancyValue.unavailable,
    _ => OccupancyValue.unknown,
  };
}

enum SensorHealth {
  healthy,
  degraded,
  failed,
  unknown;

  static SensorHealth parse(Object? value) => switch (value) {
    'HEALTHY' => SensorHealth.healthy,
    'DEGRADED' => SensorHealth.degraded,
    'FAILED' => SensorHealth.failed,
    _ => SensorHealth.unknown,
  };
}

enum ConflictType {
  spaceNotAvailable,
  unexpectedOccupancy,
  expectedOccupancyMissing,
  overstay,
  unknown;

  static ConflictType parse(Object? value) => switch (value) {
    'SPACE_NOT_AVAILABLE' => ConflictType.spaceNotAvailable,
    'UNEXPECTED_OCCUPANCY' => ConflictType.unexpectedOccupancy,
    'EXPECTED_OCCUPANCY_MISSING' => ConflictType.expectedOccupancyMissing,
    'OVERSTAY' => ConflictType.overstay,
    _ => ConflictType.unknown,
  };
}

enum MonitoringStatus {
  open,
  acknowledged,
  closed,
  resolved,
  unknown;

  static MonitoringStatus parse(Object? value) => switch (value) {
    'OPEN' => MonitoringStatus.open,
    'ACKNOWLEDGED' => MonitoringStatus.acknowledged,
    'CLOSED' => MonitoringStatus.closed,
    'RESOLVED' => MonitoringStatus.resolved,
    _ => MonitoringStatus.unknown,
  };
}

enum MonitoringSeverity {
  low,
  medium,
  high,
  critical,
  unknown;

  static MonitoringSeverity parse(Object? value) => switch (value) {
    'LOW' => MonitoringSeverity.low,
    'MEDIUM' => MonitoringSeverity.medium,
    'HIGH' => MonitoringSeverity.high,
    'CRITICAL' => MonitoringSeverity.critical,
    _ => MonitoringSeverity.unknown,
  };
}

enum OccupancyReportStatus {
  generated,
  unknown;

  static OccupancyReportStatus parse(Object? value) => switch (value) {
    'GENERATED' => OccupancyReportStatus.generated,
    _ => OccupancyReportStatus.unknown,
  };
}

enum ResolutionClassification {
  unauthorizedOccupancy,
  reservationReassigned,
  sensorRecovered,
  falsePositive,
  other,
  unknown;

  static ResolutionClassification parse(Object? value) => switch (value) {
    'UNAUTHORIZED_OCCUPANCY' => ResolutionClassification.unauthorizedOccupancy,
    'RESERVATION_REASSIGNED' => ResolutionClassification.reservationReassigned,
    'SENSOR_RECOVERED' => ResolutionClassification.sensorRecovered,
    'FALSE_POSITIVE' => ResolutionClassification.falsePositive,
    'OTHER' => ResolutionClassification.other,
    _ => ResolutionClassification.unknown,
  };
}

enum AlertType {
  sensorFailure,
  occupancyConflict,
  unknown;

  static AlertType parse(Object? value) => switch (value) {
    'SENSOR_FAILURE' => AlertType.sensorFailure,
    'OCCUPANCY_CONFLICT' => AlertType.occupancyConflict,
    _ => AlertType.unknown,
  };
}

class MonitoringSensor {
  const MonitoringSensor({
    required this.sensorId,
    required this.tenantId,
    required this.zoneId,
    required this.spotId,
    required this.protocol,
    required this.status,
    required this.lastSeenAt,
    required this.configuration,
    required this.installedAt,
  });

  factory MonitoringSensor.fromJson(MonitoringJson json) => MonitoringSensor(
    sensorId: _string(json, 'sensorId'),
    tenantId: _string(json, 'tenantId'),
    zoneId: _string(json, 'zoneId'),
    spotId: _string(json, 'spotId'),
    protocol: SensorProtocol.parse(json['protocol']),
    status: SensorStatus.parse(json['status']),
    lastSeenAt: _date(json['lastSeenAt']),
    configuration: _map(json['configuration']),
    installedAt: _date(json['installedAt']),
  );

  final String sensorId;
  final String tenantId;
  final String zoneId;
  final String spotId;
  final SensorProtocol protocol;
  final SensorStatus status;
  final DateTime? lastSeenAt;
  final MonitoringJson configuration;
  final DateTime? installedAt;
}

class OccupancyReading {
  const OccupancyReading({
    required this.readingId,
    required this.sensorId,
    required this.spotId,
    required this.occupancyStatus,
    required this.occurredAt,
    required this.receivedAt,
    required this.quality,
    required this.payloadHash,
  });

  factory OccupancyReading.fromJson(MonitoringJson json) => OccupancyReading(
    readingId: _string(json, 'readingId'),
    sensorId: _string(json, 'sensorId'),
    spotId: _string(json, 'spotId'),
    occupancyStatus: OccupancyValue.parse(json['occupancyStatus']),
    occurredAt: _date(json['occurredAt']),
    receivedAt: _date(json['receivedAt']),
    quality: (json['quality'] as num?)?.toDouble() ?? 0,
    payloadHash: _string(json, 'payloadHash'),
  );

  final String readingId;
  final String sensorId;
  final String spotId;
  final OccupancyValue occupancyStatus;
  final DateTime? occurredAt;
  final DateTime? receivedAt;
  final double quality;
  final String payloadHash;
}

class SensorHealthEvent {
  const SensorHealthEvent({
    required this.healthEventId,
    required this.sensorId,
    required this.health,
    required this.reason,
    required this.observedAt,
    required this.recoveredAt,
  });

  factory SensorHealthEvent.fromJson(MonitoringJson json) => SensorHealthEvent(
    healthEventId: _string(json, 'healthEventId'),
    sensorId: _string(json, 'sensorId'),
    health: SensorHealth.parse(json['health']),
    reason: _string(json, 'reason'),
    observedAt: _date(json['observedAt']),
    recoveredAt: _date(json['recoveredAt']),
  );

  final String healthEventId;
  final String sensorId;
  final SensorHealth health;
  final String reason;
  final DateTime? observedAt;
  final DateTime? recoveredAt;
}

class OccupancyConflict {
  const OccupancyConflict({
    required this.conflictId,
    required this.spotId,
    required this.reservationId,
    required this.readingId,
    required this.tenantId,
    required this.conflictType,
    required this.severity,
    required this.detectedAt,
    required this.status,
  });

  factory OccupancyConflict.fromJson(MonitoringJson json) => OccupancyConflict(
    conflictId: _string(json, 'conflictId'),
    spotId: _string(json, 'spotId'),
    reservationId: json['reservationId'] as String?,
    readingId: _string(json, 'readingId'),
    tenantId: _string(json, 'tenantId'),
    conflictType: ConflictType.parse(json['conflictType']),
    severity: MonitoringSeverity.parse(json['severity']),
    detectedAt: _date(json['detectedAt']),
    status: MonitoringStatus.parse(json['status']),
  );

  final String conflictId;
  final String spotId;
  final String? reservationId;
  final String readingId;
  final String tenantId;
  final ConflictType conflictType;
  final MonitoringSeverity severity;
  final DateTime? detectedAt;
  final MonitoringStatus status;
}

class OccupancyAlert {
  const OccupancyAlert({
    required this.alertId,
    required this.tenantId,
    required this.healthEventId,
    required this.conflictId,
    required this.spotId,
    required this.alertType,
    required this.severity,
    required this.evidenceRef,
    required this.createdAt,
    required this.acknowledgedAt,
    required this.closedAt,
    required this.resolutionClassification,
    required this.resolutionAction,
    required this.status,
  });

  factory OccupancyAlert.fromJson(MonitoringJson json) => OccupancyAlert(
    alertId: _string(json, 'alertId'),
    tenantId: _string(json, 'tenantId'),
    healthEventId: json['healthEventId'] as String?,
    conflictId: json['conflictId'] as String?,
    spotId: _string(json, 'spotId'),
    alertType: AlertType.parse(json['alertType']),
    severity: MonitoringSeverity.parse(json['severity']),
    evidenceRef: json['evidenceRef'] as String?,
    createdAt: _date(json['createdAt']),
    acknowledgedAt: _date(json['acknowledgedAt']),
    closedAt: _date(json['closedAt']),
    resolutionClassification: ResolutionClassification.parse(
      json['resolutionClassification'],
    ),
    resolutionAction: json['resolutionAction'] as String?,
    status: MonitoringStatus.parse(json['status']),
  );

  final String alertId;
  final String tenantId;
  final String? healthEventId;
  final String? conflictId;
  final String spotId;
  final AlertType alertType;
  final MonitoringSeverity severity;
  final String? evidenceRef;
  final DateTime? createdAt;
  final DateTime? acknowledgedAt;
  final DateTime? closedAt;
  final ResolutionClassification resolutionClassification;
  final String? resolutionAction;
  final MonitoringStatus status;
}

class CapacitySnapshot {
  const CapacitySnapshot({
    required this.snapshotId,
    required this.tenantId,
    required this.zoneId,
    required this.occupiedCount,
    required this.totalCount,
    required this.percentage,
    required this.observedAt,
  });

  factory CapacitySnapshot.fromJson(MonitoringJson json) => CapacitySnapshot(
    snapshotId: _string(json, 'snapshotId'),
    tenantId: _string(json, 'tenantId'),
    zoneId: json['zoneId'] as String?,
    occupiedCount: _integer(json['occupiedCount']),
    totalCount: _integer(json['totalCount']),
    percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
    observedAt: _date(json['observedAt']),
  );

  final String snapshotId;
  final String tenantId;
  final String? zoneId;
  final int occupiedCount;
  final int totalCount;
  final double percentage;
  final DateTime? observedAt;
}

class CapacityAlert {
  const CapacityAlert({
    required this.capacityAlertId,
    required this.tenantId,
    required this.zoneId,
    required this.snapshotId,
    required this.thresholdPercentage,
    required this.occupancyPercentage,
    required this.severity,
    required this.status,
    required this.createdAt,
    required this.acknowledgedAt,
    required this.resolvedAt,
  });

  factory CapacityAlert.fromJson(MonitoringJson json) => CapacityAlert(
    capacityAlertId: _string(json, 'capacityAlertId'),
    tenantId: _string(json, 'tenantId'),
    zoneId: json['zoneId'] as String?,
    snapshotId: _string(json, 'snapshotId'),
    thresholdPercentage: (json['thresholdPercentage'] as num?)?.toDouble() ?? 0,
    occupancyPercentage: (json['occupancyPercentage'] as num?)?.toDouble() ?? 0,
    severity: MonitoringSeverity.parse(json['severity']),
    status: MonitoringStatus.parse(json['status']),
    createdAt: _date(json['createdAt']),
    acknowledgedAt: _date(json['acknowledgedAt']),
    resolvedAt: _date(json['resolvedAt']),
  );

  final String capacityAlertId;
  final String tenantId;
  final String? zoneId;
  final String snapshotId;
  final double thresholdPercentage;
  final double occupancyPercentage;
  final MonitoringSeverity severity;
  final MonitoringStatus status;
  final DateTime? createdAt;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
}

class OccupancyReport {
  const OccupancyReport({
    required this.reportId,
    required this.tenantId,
    required this.zoneId,
    required this.intervalStart,
    required this.intervalEnd,
    required this.totals,
    required this.generatedAt,
    required this.status,
  });

  factory OccupancyReport.fromJson(MonitoringJson json) => OccupancyReport(
    reportId: _string(json, 'reportId'),
    tenantId: _string(json, 'tenantId'),
    zoneId: _string(json, 'zoneId'),
    intervalStart: _date(json['intervalStart']),
    intervalEnd: _date(json['intervalEnd']),
    totals: _map(json['totals']),
    generatedAt: _date(json['generatedAt']),
    status: OccupancyReportStatus.parse(json['status']),
  );

  final String reportId;
  final String tenantId;
  final String zoneId;
  final DateTime? intervalStart;
  final DateTime? intervalEnd;
  final MonitoringJson totals;
  final DateTime? generatedAt;
  final OccupancyReportStatus status;

  bool get isEmptyOrZero => totals.isEmpty || totals.values.every(_isZero);
}

class SpotObservation {
  const SpotObservation({
    required this.spotId,
    required this.occupancy,
    required this.readingId,
    required this.occurredAt,
    required this.reason,
  });

  factory SpotObservation.fromJson(MonitoringJson json) => SpotObservation(
    spotId: _string(json, 'spotId'),
    occupancy: OccupancyValue.parse(json['occupancy']),
    readingId: json['readingId'] as String?,
    occurredAt: _date(json['occurredAt']),
    reason: _string(json, 'reason'),
  );

  final String spotId;
  final OccupancyValue occupancy;
  final String? readingId;
  final DateTime? occurredAt;
  final String reason;
}

class ParkingMapElement {
  const ParkingMapElement({
    required this.spotId,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.rotation,
    required this.label,
  });

  factory ParkingMapElement.fromJson(MonitoringJson json) => ParkingMapElement(
    spotId: _string(json, 'spot_id'),
    x: (json['x'] as num?)?.toDouble() ?? 0,
    y: (json['y'] as num?)?.toDouble() ?? 0,
    w: (json['w'] as num?)?.toDouble() ?? 0,
    h: (json['h'] as num?)?.toDouble() ?? 0,
    rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
    label: _string(json, 'label'),
  );

  final String spotId;
  final double x;
  final double y;
  final double w;
  final double h;
  final double rotation;
  final String label;
}

class ParkingMapLayout {
  const ParkingMapLayout(this.elements);

  final List<ParkingMapElement> elements;
}

String _string(MonitoringJson json, String key) =>
    json[key] is String ? json[key] as String : '';
int _integer(Object? value) => value is num ? value.toInt() : 0;
DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
MonitoringJson _map(Object? value) =>
    value is MonitoringJson ? value : const {};
bool _isZero(Object? value) =>
    value == null ||
    value == false ||
    value == 0 ||
    value == 0.0 ||
    value == '0' ||
    value == '0.0' ||
    value == '' ||
    value is Map && value.values.every(_isZero) ||
    value is Iterable && value.every(_isZero);
