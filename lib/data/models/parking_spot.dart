enum SpotType {
  standard('STD', 'Standard'),
  covered('COV', 'Covered'),
  ev('EV', 'EV'),
  accessible('ACC', 'Accessible');

  const SpotType(this.code, this.label);

  final String code;
  final String label;
}

/// Physical state reported by the occupancy sensor.
enum OccupancyStatus {
  available('Available'),
  occupied('Occupied'),
  unavailable('Unavailable'),
  unknown('Unknown');

  const OccupancyStatus(this.label);

  final String label;
}

/// Reservation lifecycle seen from the spot, kept apart from occupancy.
enum ReservationState {
  none('No reservation'),
  reserved('Reserved'),
  active('Active reservation');

  const ReservationState(this.label);

  final String label;
}

enum SensorHealth {
  healthy('Online'),
  degraded('Degraded'),
  failed('Offline'),
  noSensor('No active sensor'),
  unknown('Unknown');

  const SensorHealth(this.label);

  final String label;
}

/// Availability shown to operators, derived from the independent states.
enum SpotAvailability {
  available('Available'),
  reserved('Reserved'),
  occupied('Occupied'),
  unavailable('Unavailable');

  const SpotAvailability(this.label);

  final String label;
}

class ParkingSpot {
  const ParkingSpot({
    required this.id,
    required this.code,
    required this.zoneId,
    required this.type,
    required this.occupancy,
    required this.reservation,
    required this.sensorId,
    required this.sensorHealth,
    required this.lastReadingAt,
    this.bookable = true,
    this.operationalStatus = 'ACTIVE',
    this.availabilityReason = '',
    this.sensorHealthReason = '',
    this.reservationCode,
    this.guestSessionId,
  });

  final String id;
  final String code;
  final String zoneId;
  final SpotType type;
  final OccupancyStatus occupancy;
  final ReservationState reservation;
  final String? reservationCode;
  final String sensorId;
  final SensorHealth sensorHealth;
  final DateTime lastReadingAt;
  final bool bookable;
  final String operationalStatus;
  final String availabilityReason;
  final String sensorHealthReason;
  final String? guestSessionId;

  bool get sensorReliable =>
      sensorHealth == SensorHealth.healthy ||
      sensorHealth == SensorHealth.degraded;

  SpotAvailability get availability {
    if (!sensorReliable ||
        occupancy == OccupancyStatus.unavailable ||
        occupancy == OccupancyStatus.unknown) {
      return SpotAvailability.unavailable;
    }
    if (occupancy == OccupancyStatus.occupied ||
        guestSessionId != null ||
        reservation == ReservationState.active) {
      return SpotAvailability.occupied;
    }
    if (reservation == ReservationState.reserved) {
      return SpotAvailability.reserved;
    }
    return SpotAvailability.available;
  }

  bool get canStartGuestSession =>
      bookable && availability == SpotAvailability.available;

  String get availabilityReasonLabel {
    if (availabilityReason.isEmpty) return 'Availability unavailable';
    return _reasonLabel(availabilityReason);
  }

  String get sensorHealthReasonLabel =>
      sensorHealthReason.isEmpty ? '' : _reasonLabel(sensorHealthReason);

  static String _reasonLabel(String reason) {
    const knownReasons = {
      'FUTURE_SLOT_NO_KNOWN_BLOCK': 'No known block for this time slot',
      'RESERVATION_OR_OPEN_STAY': 'Reservation or guest session in progress',
      'NO_ACTIVE_SENSOR': 'No active sensor',
    };
    return knownReasons[reason] ??
        reason
            .replaceAll('_', ' ')
            .toLowerCase()
            .replaceFirstMapped(
              RegExp(r'^[a-z]'),
              (match) => match[0]!.toUpperCase(),
            );
  }

  /// Occupied without an active reservation or guest session (US06).
  bool get hasUnvalidatedOccupancy =>
      sensorReliable &&
      occupancy == OccupancyStatus.occupied &&
      reservation != ReservationState.active &&
      guestSessionId == null;

  bool get hasIssue =>
      !sensorReliable ||
      occupancy == OccupancyStatus.unavailable ||
      occupancy == OccupancyStatus.unknown ||
      hasUnvalidatedOccupancy;

  ParkingSpot copyWith({
    String? zoneId,
    OccupancyStatus? occupancy,
    ReservationState? reservation,
    SensorHealth? sensorHealth,
    bool? bookable,
    String? availabilityReason,
    String? sensorHealthReason,
    DateTime? lastReadingAt,
    String? guestSessionId,
    bool clearGuestSession = false,
  }) {
    return ParkingSpot(
      id: id,
      code: code,
      zoneId: zoneId ?? this.zoneId,
      type: type,
      occupancy: occupancy ?? this.occupancy,
      reservation: reservation ?? this.reservation,
      reservationCode: reservationCode,
      sensorId: sensorId,
      sensorHealth: sensorHealth ?? this.sensorHealth,
      lastReadingAt: lastReadingAt ?? this.lastReadingAt,
      bookable: bookable ?? this.bookable,
      operationalStatus: operationalStatus,
      availabilityReason: availabilityReason ?? this.availabilityReason,
      sensorHealthReason: sensorHealthReason ?? this.sensorHealthReason,
      guestSessionId: clearGuestSession
          ? null
          : guestSessionId ?? this.guestSessionId,
    );
  }
}
