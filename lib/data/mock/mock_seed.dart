import '../models/guest_session.dart';
import '../models/operational_alert.dart';
import '../models/parking_spot.dart';
import '../models/parking_zone.dart';

class MockSeedData {
  const MockSeedData({
    required this.zones,
    required this.spots,
    required this.alerts,
    required this.sessions,
  });

  final List<ParkingZone> zones;
  final List<ParkingSpot> spots;
  final List<OperationalAlert> alerts;
  final List<GuestSession> sessions;
}

/// Sample facility inspired by the Parking Admin mockups. Times are relative
/// to [build]'s `now` so the demo always looks current.
abstract final class MockSeed {
  static const facilityName = 'Javier Prado Parking';
  static const district = 'San Isidro';
  static const outstandingBalances = 2;

  static MockSeedData build(DateTime now) {
    DateTime ago(int minutes) => now.subtract(Duration(minutes: minutes));

    ParkingSpot spot(
      String code,
      SpotType type, {
      OccupancyStatus occupancy = OccupancyStatus.available,
      ReservationState reservation = ReservationState.none,
      String? reservationCode,
      SensorHealth health = SensorHealth.healthy,
      String? guest,
    }) {
      return ParkingSpot(
        id: code,
        code: code,
        zoneId: 'Z-${code[0]}',
        type: type,
        occupancy: health == SensorHealth.failed
            ? OccupancyStatus.unavailable
            : occupancy,
        reservation: reservation,
        reservationCode: reservationCode,
        sensorId: 'SEN-JP-${code.replaceAll('-', '')}',
        sensorHealth: health,
        lastReadingAt: health == SensorHealth.failed ? ago(38) : ago(0),
        guestSessionId: guest,
      );
    }

    const occ = OccupancyStatus.occupied;
    const res = ReservationState.reserved;
    const act = ReservationState.active;

    final spots = [
      spot('A-01', SpotType.standard),
      spot(
        'A-02',
        SpotType.standard,
        occupancy: occ,
        reservation: act,
        reservationCode: 'SG-4790',
      ),
      spot('A-03', SpotType.ev, reservation: res, reservationCode: 'SG-4821'),
      spot('A-04', SpotType.accessible),
      spot(
        'A-05',
        SpotType.standard,
        occupancy: occ,
        reservation: act,
        reservationCode: 'SG-4802',
      ),
      spot('A-06', SpotType.standard, occupancy: occ, guest: 'GP-1046'),
      spot('A-07', SpotType.standard, occupancy: occ),
      spot('A-08', SpotType.standard),
      spot('B-01', SpotType.covered, occupancy: occ, guest: 'GP-1048'),
      spot(
        'B-02',
        SpotType.covered,
        occupancy: occ,
        reservation: act,
        reservationCode: 'SG-4811',
      ),
      spot('B-03', SpotType.standard, occupancy: occ, guest: 'GP-1049'),
      spot('B-04', SpotType.covered),
      spot(
        'B-05',
        SpotType.standard,
        occupancy: occ,
        reservation: act,
        reservationCode: 'SG-4815',
      ),
      spot(
        'B-06',
        SpotType.covered,
        reservation: res,
        reservationCode: 'SG-4830',
      ),
      spot(
        'B-07',
        SpotType.standard,
        occupancy: occ,
        reservation: act,
        reservationCode: 'SG-4818',
      ),
      spot('B-08', SpotType.standard, health: SensorHealth.failed),
      spot(
        'C-01',
        SpotType.standard,
        occupancy: occ,
        reservation: act,
        reservationCode: 'SG-4820',
      ),
      spot('C-02', SpotType.standard),
      spot(
        'C-03',
        SpotType.accessible,
        occupancy: occ,
        reservation: act,
        reservationCode: 'SG-4823',
      ),
      spot(
        'C-04',
        SpotType.standard,
        occupancy: occ,
        reservation: act,
        reservationCode: 'SG-4825',
      ),
      spot(
        'C-05',
        SpotType.standard,
        health: SensorHealth.failed,
        guest: 'GP-1047',
      ),
      spot('C-06', SpotType.ev),
      spot(
        'C-07',
        SpotType.standard,
        occupancy: occ,
        reservation: act,
        reservationCode: 'SG-4827',
      ),
      spot(
        'C-08',
        SpotType.standard,
        occupancy: occ,
        reservation: act,
        reservationCode: 'SG-4828',
      ),
    ];

    List<String> idsOf(String prefix) => [
      for (final s in spots)
        if (s.code.startsWith(prefix)) s.id,
    ];

    final zones = [
      ParkingZone(
        id: 'Z-A',
        name: 'Zone A · Level 1',
        address: 'Av. Javier Prado Oeste 607',
        district: district,
        opensAtMinutes: 7 * 60,
        closesAtMinutes: 23 * 60,
        ratePerHour: 8,
        billingFractionMinutes: 30,
        status: ZoneStatus.active,
        allowedTypes: const {
          SpotType.standard,
          SpotType.ev,
          SpotType.accessible,
        },
        authorizedProfiles: const {
          AccessProfile.standard,
          AccessProfile.subscriber,
          AccessProfile.accessible,
        },
        spotIds: idsOf('A'),
      ),
      ParkingZone(
        id: 'Z-B',
        name: 'Zone B · Level 1',
        address: 'Av. Javier Prado Oeste 607',
        district: district,
        opensAtMinutes: 7 * 60,
        closesAtMinutes: 23 * 60,
        ratePerHour: 9,
        billingFractionMinutes: 30,
        status: ZoneStatus.active,
        allowedTypes: const {SpotType.standard, SpotType.covered},
        authorizedProfiles: const {
          AccessProfile.subscriber,
          AccessProfile.tenantStaff,
        },
        spotIds: idsOf('B'),
      ),
      ParkingZone(
        id: 'Z-C',
        name: 'Zone C · Level 2',
        address: 'Av. Javier Prado Oeste 607',
        district: district,
        opensAtMinutes: 6 * 60,
        closesAtMinutes: 22 * 60,
        ratePerHour: 7,
        billingFractionMinutes: 15,
        status: ZoneStatus.active,
        allowedTypes: const {
          SpotType.standard,
          SpotType.ev,
          SpotType.accessible,
        },
        authorizedProfiles: const {
          AccessProfile.standard,
          AccessProfile.accessible,
        },
        spotIds: idsOf('C'),
      ),
    ];

    final sessions = [
      GuestSession(
        id: 'GP-1046',
        plate: 'B7N-216',
        vehicleType: VehicleType.car,
        color: 'Gray',
        zoneId: 'Z-A',
        spotId: 'A-06',
        spotCode: 'A-06',
        entryAt: ago(102),
        expectedDuration: const Duration(hours: 2),
        status: GuestSessionStatus.open,
      ),
      GuestSession(
        id: 'GP-1048',
        plate: 'C4R-831',
        vehicleType: VehicleType.van,
        color: 'White',
        zoneId: 'Z-B',
        spotId: 'B-01',
        spotCode: 'B-01',
        entryAt: ago(130),
        expectedDuration: const Duration(hours: 2),
        status: GuestSessionStatus.open,
      ),
      GuestSession(
        id: 'GP-1049',
        plate: 'D2P-504',
        vehicleType: VehicleType.car,
        color: 'Blue',
        zoneId: 'Z-B',
        spotId: 'B-03',
        spotCode: 'B-03',
        entryAt: ago(55),
        expectedDuration: const Duration(hours: 1),
        status: GuestSessionStatus.open,
      ),
      GuestSession(
        id: 'GP-1047',
        plate: 'E5K-118',
        vehicleType: VehicleType.car,
        color: 'Black',
        zoneId: 'Z-C',
        spotId: 'C-05',
        spotCode: 'C-05',
        entryAt: ago(75),
        expectedDuration: const Duration(hours: 3),
        status: GuestSessionStatus.pendingReview,
      ),
      GuestSession(
        id: 'GP-1043',
        plate: 'F9T-402',
        vehicleType: VehicleType.car,
        color: 'Red',
        zoneId: 'Z-A',
        spotId: 'A-01',
        spotCode: 'A-01',
        entryAt: ago(260),
        expectedDuration: const Duration(hours: 1),
        exitAt: ago(195),
        amount: 12,
        paymentMethod: PhysicalPaymentMethod.cash,
        paymentConfirmed: true,
        status: GuestSessionStatus.closed,
      ),
      GuestSession(
        id: 'GP-1040',
        plate: 'H3M-775',
        vehicleType: VehicleType.motorcycle,
        zoneId: 'Z-C',
        spotId: 'C-02',
        spotCode: 'C-02',
        entryAt: ago(340),
        expectedDuration: const Duration(hours: 2),
        exitAt: ago(232),
        amount: 14,
        paymentMethod: PhysicalPaymentMethod.externalPos,
        paymentConfirmed: true,
        paymentReference: 'POS-88213',
        status: GuestSessionStatus.closed,
      ),
    ];

    OperationalAlert alert({
      required String id,
      required AlertType type,
      required AlertSeverity severity,
      required String description,
      required String zoneId,
      String? spotCode,
      required String source,
      required int minutesAgo,
      AlertStatus status = AlertStatus.open,
      String? classification,
      String? action,
    }) {
      final detected = ago(minutesAgo);
      return OperationalAlert(
        id: id,
        type: type,
        severity: severity,
        description: description,
        zoneId: zoneId,
        spotCode: spotCode,
        source: source,
        detectedAt: detected,
        status: status,
        classification: classification,
        actionTaken: action,
        history: [
          AlertEvent(
            at: detected,
            actor: 'System',
            description: 'Alert created',
          ),
          if (status == AlertStatus.resolved)
            AlertEvent(
              at: detected.add(const Duration(minutes: 12)),
              actor: 'Parking Admin Demo',
              description: 'Resolved as "$classification": $action',
            ),
        ],
      );
    }

    final alerts = [
      alert(
        id: 'AL-2001',
        type: AlertType.sensorOffline,
        severity: AlertSeverity.high,
        description: '$facilityName · Spot B-08 marked Unavailable.',
        zoneId: 'Z-B',
        spotCode: 'B-08',
        source: 'SEN-JP-B08 · Offline',
        minutesAgo: 2,
      ),
      alert(
        id: 'AL-2002',
        type: AlertType.overstay,
        severity: AlertSeverity.medium,
        description:
            '$facilityName · 5-minute tolerance passed for session GP-1048.',
        zoneId: 'Z-B',
        spotCode: 'B-01',
        source: 'Guest session GP-1048',
        minutesAgo: 8,
      ),
      alert(
        id: 'AL-2003',
        type: AlertType.paymentIssue,
        severity: AlertSeverity.medium,
        description: 'Reservation SG-4821 · Outstanding balance S/ 16.00.',
        zoneId: 'Z-A',
        spotCode: 'A-03',
        source: 'Reservation SG-4821',
        minutesAgo: 21,
      ),
      alert(
        id: 'AL-2004',
        type: AlertType.spotUnavailable,
        severity: AlertSeverity.info,
        description:
            '$facilityName · Spot C-05 sensor data is not reliable; '
            'automatic overstay charges paused.',
        zoneId: 'Z-C',
        spotCode: 'C-05',
        source: 'SEN-JP-C05 · Offline',
        minutesAgo: 36,
      ),
      alert(
        id: 'AL-2005',
        type: AlertType.unauthorizedOccupancy,
        severity: AlertSeverity.high,
        description:
            'Spot A-07 occupied without a valid reservation or guest session.',
        zoneId: 'Z-A',
        spotCode: 'A-07',
        source: 'SEN-JP-A07 · Occupied',
        minutesAgo: 41,
      ),
      alert(
        id: 'AL-1998',
        type: AlertType.reservationConflict,
        severity: AlertSeverity.medium,
        description: 'Reservation SG-4790 overlapped a previous session.',
        zoneId: 'Z-A',
        spotCode: 'A-02',
        source: 'Reservation SG-4790',
        minutesAgo: 180,
        status: AlertStatus.resolved,
        classification: 'Spot reassigned',
        action: 'Driver reassigned to spot A-02 and notified',
      ),
    ];

    return MockSeedData(
      zones: zones,
      spots: spots,
      alerts: alerts,
      sessions: sessions,
    );
  }
}
