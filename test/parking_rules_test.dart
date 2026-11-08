import 'package:flutter_test/flutter_test.dart';

import 'package:spotgo_mobile_app/data/models/guest_session.dart';
import 'package:spotgo_mobile_app/data/models/parking_spot.dart';
import 'package:spotgo_mobile_app/data/models/parking_zone.dart';
import 'package:spotgo_mobile_app/domain/parking_rules.dart';

ParkingSpot _spot(
  String code, {
  OccupancyStatus occupancy = OccupancyStatus.available,
  ReservationState reservation = ReservationState.none,
  SensorHealth sensorHealth = SensorHealth.healthy,
  String? guestSessionId,
}) => ParkingSpot(
  id: code,
  code: code,
  zoneId: 'Z-A',
  type: SpotType.standard,
  occupancy: occupancy,
  reservation: reservation,
  sensorId: 'S-$code',
  sensorHealth: sensorHealth,
  lastReadingAt: DateTime.utc(2026, 1, 1),
  guestSessionId: guestSessionId,
);

ParkingZone _zone(String id, List<String> spotIds) => ParkingZone(
  id: id,
  name: 'Zone $id',
  address: 'Main avenue',
  district: 'San Isidro',
  opensAtMinutes: 420,
  closesAtMinutes: 1380,
  ratePerHour: 8,
  billingFractionMinutes: 30,
  status: ZoneStatus.active,
  allowedTypes: const {SpotType.standard},
  authorizedProfiles: const {AccessProfile.standard},
  spotIds: spotIds,
);

void main() {
  group('license plates', () {
    test('normalizes six characters and accepts six or seven', () {
      expect(ParkingRules.normalizePlate(' ab c-123 '), 'ABC-123');
      expect(ParkingRules.normalizePlate('abc1234'), 'ABC1234');
      expect(ParkingRules.validatePlate(' b7n-216 '), isNull);
      expect(ParkingRules.validatePlate('ABC1234'), isNull);
    });

    test('rejects empty and malformed plates', () {
      expect(ParkingRules.validatePlate(null), 'Enter the license plate');
      expect(ParkingRules.validatePlate('ABC-12'), isNotNull);
      expect(ParkingRules.validatePlate('ABC-12!'), isNotNull);
    });
  });

  group('guest billing', () {
    final entry = DateTime.utc(2026, 1, 1, 12);

    double amount(DateTime exit, {double rate = 8, int fraction = 30}) =>
        ParkingRules.guestAmount(
          entryAt: entry,
          exitAt: exit,
          ratePerHour: rate,
          billingFractionMinutes: fraction,
        );

    test('charges at least one fraction and rounds up elapsed fractions', () {
      expect(amount(entry), 4);
      expect(amount(entry.add(const Duration(minutes: 30))), 4);
      expect(amount(entry.add(const Duration(minutes: 31))), 8);
      expect(
        amount(
          entry.add(const Duration(minutes: 21)),
          rate: 7.33,
          fraction: 20,
        ),
        4.89,
      );
    });

    test('rejects nonpositive billing fractions', () {
      expect(
        () => amount(entry, fraction: 0),
        throwsA(isA<ParkingRuleException>()),
      );
      expect(
        () => amount(entry, fraction: -1),
        throwsA(isA<ParkingRuleException>()),
      );
    });
  });

  test('occupancy uses only reliable physical readings and exceeds 95%', () {
    final nineteen = [
      for (var i = 0; i < 20; i++)
        _spot(
          'S-$i',
          occupancy: i == 19
              ? OccupancyStatus.available
              : OccupancyStatus.occupied,
        ),
      _spot('unavailable', occupancy: OccupancyStatus.unavailable),
      _spot(
        'failed',
        occupancy: OccupancyStatus.occupied,
        sensorHealth: SensorHealth.failed,
      ),
    ];
    expect(ParkingRules.occupancyRatio(nineteen), 0.95);
    expect(ParkingRules.isHighOccupancy(nineteen), isFalse);
    final twenty = List<ParkingSpot>.of(nineteen);
    twenty[19] = _spot('S-19', occupancy: OccupancyStatus.occupied);
    expect(ParkingRules.occupancyRatio(twenty), 1);
    expect(ParkingRules.isHighOccupancy(twenty), isTrue);
    expect(
      ParkingRules.occupancyRatio([
        _spot('reserved', reservation: ReservationState.reserved),
        _spot('guest', guestSessionId: 'GP-1'),
        _spot('occupied', occupancy: OccupancyStatus.occupied),
      ]),
      closeTo(1 / 3, 0.000001),
    );
    expect(ParkingRules.occupancyRatio([]), 0);
  });

  test('operating hours require both values and a later closing time', () {
    expect(ParkingRules.validateOperatingHours(null, 1380), isNotNull);
    expect(ParkingRules.validateOperatingHours(420, null), isNotNull);
    expect(ParkingRules.validateOperatingHours(420, 420), isNotNull);
    expect(ParkingRules.validateOperatingHours(1380, 420), isNotNull);
    expect(ParkingRules.validateOperatingHours(420, 1380), isNull);
  });

  test('conflicting spots exclude the zone being edited', () {
    final zones = [
      _zone('Z-A', ['A-01']),
      _zone('Z-B', ['B-01']),
    ];
    expect(
      ParkingRules.conflictingSpots(
        zoneId: 'Z-A',
        selectedSpotIds: ['A-01', 'B-01'],
        zones: zones,
      ),
      ['B-01'],
    );
    expect(
      ParkingRules.conflictingSpots(
        zoneId: null,
        selectedSpotIds: ['A-01'],
        zones: zones,
      ),
      ['A-01'],
    );
  });

  test('alert resolution requires classification, action, and completion', () {
    String? error(String? classification, String? action, bool completed) =>
        ParkingRules.validateAlertResolution(
          classification: classification,
          action: action,
          actionCompleted: completed,
        );
    expect(error(null, 'Reset sensor', true), isNotNull);
    expect(error('Sensor offline', 'test', true), isNotNull);
    expect(error('Sensor offline', 'Reset sensor', false), isNotNull);
    expect(error('Sensor offline', 'Reset sensor', true), isNull);
  });

  test(
    'spot availability keeps sensor, reservation and guest states distinct',
    () {
      expect(_spot('free').availability, SpotAvailability.available);
      expect(
        _spot('reserved', reservation: ReservationState.reserved).availability,
        SpotAvailability.reserved,
      );
      expect(
        _spot('occupied', occupancy: OccupancyStatus.occupied).availability,
        SpotAvailability.occupied,
      );
      expect(
        _spot('active', reservation: ReservationState.active).availability,
        SpotAvailability.occupied,
      );
      expect(
        _spot('guest', guestSessionId: 'GP-1').availability,
        SpotAvailability.occupied,
      );
      expect(
        _spot('failed', sensorHealth: SensorHealth.failed).availability,
        SpotAvailability.unavailable,
      );
      expect(
        _spot(
          'unavailable',
          occupancy: OccupancyStatus.unavailable,
        ).availability,
        SpotAvailability.unavailable,
      );
    },
  );

  test(
    'unvalidated occupancy requires a reliable sensor and no valid link',
    () {
      expect(
        _spot(
          'unlinked',
          occupancy: OccupancyStatus.occupied,
        ).hasUnvalidatedOccupancy,
        isTrue,
      );
      expect(
        _spot(
          'reserved',
          occupancy: OccupancyStatus.occupied,
          reservation: ReservationState.reserved,
        ).hasUnvalidatedOccupancy,
        isTrue,
      );
      expect(
        _spot(
          'active',
          occupancy: OccupancyStatus.occupied,
          reservation: ReservationState.active,
        ).hasUnvalidatedOccupancy,
        isFalse,
      );
      expect(
        _spot(
          'guest',
          occupancy: OccupancyStatus.occupied,
          guestSessionId: 'GP-1',
        ).hasUnvalidatedOccupancy,
        isFalse,
      );
      expect(
        _spot(
          'failed',
          occupancy: OccupancyStatus.occupied,
          sensorHealth: SensorHealth.failed,
        ).hasUnvalidatedOccupancy,
        isFalse,
      );
    },
  );

  test('guest overstay begins after the five-minute tolerance', () {
    final entry = DateTime.utc(2026, 1, 1, 12);
    final session = GuestSession(
      id: 'GP-1',
      plate: 'ABC-123',
      vehicleType: VehicleType.car,
      zoneId: 'Z-A',
      spotId: 'A-01',
      spotCode: 'A-01',
      entryAt: entry,
      expectedDuration: const Duration(hours: 1),
      status: GuestSessionStatus.open,
    );
    final limit = entry.add(const Duration(hours: 1, minutes: 5));
    expect(session.isOverstay(limit), isFalse);
    expect(session.isOverstay(limit.add(const Duration(seconds: 1))), isTrue);
    expect(
      session
          .copyWith(status: GuestSessionStatus.closed)
          .isOverstay(limit.add(const Duration(hours: 1))),
      isFalse,
    );
  });
}
