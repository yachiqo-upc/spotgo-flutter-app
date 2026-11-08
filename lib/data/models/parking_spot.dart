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
  unavailable('Unavailable');

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
  failed('Offline');

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
  final String? guestSessionId;

  bool get sensorReliable => sensorHealth != SensorHealth.failed;

  SpotAvailability get availability {
    if (!sensorReliable || occupancy == OccupancyStatus.unavailable) {
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

  bool get canStartGuestSession => availability == SpotAvailability.available;

  /// Occupied without an active reservation or guest session (US06).
  bool get hasUnvalidatedOccupancy =>
      sensorReliable &&
      occupancy == OccupancyStatus.occupied &&
      reservation != ReservationState.active &&
      guestSessionId == null;

  bool get hasIssue => !sensorReliable || hasUnvalidatedOccupancy;

  ParkingSpot copyWith({
    String? zoneId,
    OccupancyStatus? occupancy,
    ReservationState? reservation,
    SensorHealth? sensorHealth,
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
      guestSessionId: clearGuestSession
          ? null
          : guestSessionId ?? this.guestSessionId,
    );
  }
}
