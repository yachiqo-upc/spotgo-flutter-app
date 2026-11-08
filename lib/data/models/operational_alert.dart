enum AlertCategory { sensor, occupancy, reservation, payment }

enum AlertType {
  sensorOffline('Sensor offline', AlertCategory.sensor, [
    'Sensor offline',
    'Power failure',
    'Connectivity issue',
    'Hardware damage',
  ]),
  spotUnavailable('Spot unavailable', AlertCategory.sensor, [
    'Unreliable sensor data',
    'Maintenance',
    'Blocked spot',
  ]),
  unauthorizedOccupancy('Unauthorized occupancy', AlertCategory.occupancy, [
    'Unauthorized vehicle',
    'Late guest registration',
    'Sensor false positive',
  ]),
  highOccupancy('High occupancy', AlertCategory.occupancy, [
    'Peak demand',
    'Event traffic',
    'Spots out of service',
  ]),
  reservationConflict('Reservation conflict', AlertCategory.reservation, [
    'Previous session overstay',
    'Spot reassigned',
    'Driver no-show',
  ]),
  overstay('Overstay detected', AlertCategory.reservation, [
    'Overstay confirmed',
    'Tolerance not exceeded',
    'Session closed late',
  ]),
  paymentIssue('Payment issue', AlertCategory.payment, [
    'Outstanding balance',
    'Payment rejected',
    'Duplicate charge review',
  ]);

  const AlertType(this.label, this.category, this.classifications);

  final String label;
  final AlertCategory category;
  final List<String> classifications;
}

enum AlertSeverity {
  high('High'),
  medium('Medium'),
  info('Info');

  const AlertSeverity(this.label);

  final String label;
}

enum AlertStatus {
  open('Open'),
  monitoring('Monitoring'),
  resolved('Resolved');

  const AlertStatus(this.label);

  final String label;
}

class AlertEvent {
  const AlertEvent({
    required this.at,
    required this.actor,
    required this.description,
  });

  final DateTime at;
  final String actor;
  final String description;
}

class OperationalAlert {
  const OperationalAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.description,
    required this.zoneId,
    required this.source,
    required this.detectedAt,
    required this.status,
    required this.history,
    this.spotCode,
    this.classification,
    this.actionTaken,
  });

  final String id;
  final AlertType type;
  final AlertSeverity severity;
  final String description;
  final String zoneId;
  final String? spotCode;

  /// Sensor, session or reservation that originated the alert.
  final String source;
  final DateTime detectedAt;
  final AlertStatus status;
  final String? classification;
  final String? actionTaken;
  final List<AlertEvent> history;

  String get title => type.label;
  bool get isPending => status != AlertStatus.resolved;
  bool get isCritical => severity == AlertSeverity.high;

  OperationalAlert copyWith({
    AlertStatus? status,
    String? classification,
    String? actionTaken,
    List<AlertEvent>? history,
  }) {
    return OperationalAlert(
      id: id,
      type: type,
      severity: severity,
      description: description,
      zoneId: zoneId,
      spotCode: spotCode,
      source: source,
      detectedAt: detectedAt,
      status: status ?? this.status,
      classification: classification ?? this.classification,
      actionTaken: actionTaken ?? this.actionTaken,
      history: history ?? this.history,
    );
  }
}
