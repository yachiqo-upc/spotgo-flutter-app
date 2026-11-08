import 'package:flutter_test/flutter_test.dart';

import 'package:spotgo_mobile_app/data/mock/mock_parking_repository.dart';
import 'package:spotgo_mobile_app/data/models/guest_session.dart';
import 'package:spotgo_mobile_app/data/models/operational_alert.dart';
import 'package:spotgo_mobile_app/data/models/parking_spot.dart';
import 'package:spotgo_mobile_app/data/repositories/parking_repository.dart';
import 'package:spotgo_mobile_app/domain/parking_rules.dart';

const _actor = 'Parking Admin Demo';

GuestSessionDraft _draft(String spotId, {String plate = 'Z9Q-731'}) =>
    GuestSessionDraft(
      plate: plate,
      vehicleType: VehicleType.car,
      spotId: spotId,
      expectedDuration: const Duration(hours: 2),
    );

void main() {
  late DateTime now;
  late MockParkingRepository repository;

  setUp(() {
    now = DateTime.utc(2026, 1, 1, 12);
    repository = MockParkingRepository(
      clock: () => now,
      latency: Duration.zero,
    );
  });

  test(
    'A-01 starts an open guest session without creating a reservation',
    () async {
      final created = await repository.startGuestSession(
        _draft('A-01', plate: 'z9q 731'),
        actor: _actor,
      );
      final snapshot = await repository.fetchSnapshot();
      final spot = snapshot.spots.singleWhere((s) => s.id == 'A-01');

      expect(created.plate, 'Z9Q-731');
      expect(created.status, GuestSessionStatus.open);
      expect(created.entryAt, now);
      expect(spot.guestSessionId, created.id);
      expect(spot.reservation, ReservationState.none);
      expect(spot.occupancy, OccupancyStatus.available);
      expect(spot.availability, SpotAvailability.occupied);
      expect(snapshot.audit.single.action, contains('Started guest session'));
    },
  );

  test('reserved, occupied and unavailable spots reject a guest', () async {
    for (final spotId in ['A-03', 'A-02', 'B-08']) {
      await expectLater(
        repository.startGuestSession(_draft(spotId), actor: _actor),
        throwsA(isA<ParkingRuleException>()),
      );
    }
    expect((await repository.fetchSnapshot()).audit, isEmpty);
  });

  test('a plate with an open session cannot be registered twice', () async {
    await repository.startGuestSession(_draft('A-01'), actor: _actor);
    await expectLater(
      repository.startGuestSession(
        _draft('A-04', plate: 'z9q 731'),
        actor: _actor,
      ),
      throwsA(isA<ParkingRuleException>()),
    );
  });

  test('payment before exit is rejected', () async {
    final session = await repository.startGuestSession(
      _draft('A-01'),
      actor: _actor,
    );
    await expectLater(
      repository.confirmGuestPayment(
        session.id,
        method: PhysicalPaymentMethod.cash,
        actor: _actor,
      ),
      throwsA(isA<ParkingRuleException>()),
    );
  });

  test(
    'exit and physical payment close the session and release its spot',
    () async {
      final session = await repository.startGuestSession(
        _draft('A-01'),
        actor: _actor,
      );
      now = now.add(const Duration(minutes: 31));
      final exited = await repository.registerGuestExit(
        session.id,
        actor: _actor,
      );
      expect(exited.exitAt, now);
      expect(exited.amount, 8);
      expect(exited.status, GuestSessionStatus.open);

      final closed = await repository.confirmGuestPayment(
        session.id,
        method: PhysicalPaymentMethod.cash,
        reference: 'R-123',
        actor: _actor,
      );
      final snapshot = await repository.fetchSnapshot();
      final spot = snapshot.spots.singleWhere((s) => s.id == 'A-01');
      expect(closed.status, GuestSessionStatus.closed);
      expect(closed.paymentConfirmed, isTrue);
      expect(closed.paymentMethod, PhysicalPaymentMethod.cash);
      expect(closed.paymentReference, 'R-123');
      expect(spot.guestSessionId, isNull);
      expect(spot.availability, SpotAvailability.available);
      expect(
        snapshot.audit.where(
          (entry) => entry.action.startsWith('Started guest session'),
        ),
        hasLength(1),
      );
      expect(
        snapshot.audit.where(
          (entry) => entry.action.startsWith('Registered exit'),
        ),
        hasLength(1),
      );
      expect(
        snapshot.audit.where(
          (entry) => entry.action.startsWith('Closed guest session'),
        ),
        hasLength(1),
      );
    },
  );

  test('a payment reference containing a card number is rejected', () async {
    final session = await repository.startGuestSession(
      _draft('A-01'),
      actor: _actor,
    );
    await repository.registerGuestExit(session.id, actor: _actor);
    await expectLater(
      repository.confirmGuestPayment(
        session.id,
        method: PhysicalPaymentMethod.externalPos,
        reference: '4111 1111 1111 1111',
        actor: _actor,
      ),
      throwsA(isA<ParkingRuleException>()),
    );
    final current = (await repository.fetchSnapshot()).guestSessions
        .singleWhere((s) => s.id == session.id);
    expect(current.isClosed, isFalse);
  });

  test('zone rejects a spot already assigned to another zone', () async {
    final zone = (await repository.fetchSnapshot()).zones.first;
    await expectLater(
      repository.saveZone(
        zone.copyWith(
          spotIds: [...zone.spotIds, 'B-04'],
          allowedTypes: {...zone.allowedTypes, SpotType.covered},
        ),
        actor: _actor,
      ),
      throwsA(isA<ParkingRuleException>()),
    );
  });

  test('zone rejects invalid hours and an unallowed spot type', () async {
    final zone = (await repository.fetchSnapshot()).zones.first;
    await expectLater(
      repository.saveZone(
        zone.copyWith(opensAtMinutes: 1380, closesAtMinutes: 420),
        actor: _actor,
      ),
      throwsA(isA<ParkingRuleException>()),
    );
    await expectLater(
      repository.saveZone(
        zone.copyWith(allowedTypes: {SpotType.ev}),
        actor: _actor,
      ),
      throwsA(isA<ParkingRuleException>()),
    );
  });

  test(
    'zone requires authorized profiles and a finite positive rate',
    () async {
      final zone = (await repository.fetchSnapshot()).zones.first;
      await expectLater(
        repository.saveZone(
          zone.copyWith(authorizedProfiles: {}),
          actor: _actor,
        ),
        throwsA(isA<ParkingRuleException>()),
      );
      for (final rate in [double.nan, double.infinity, 0.0]) {
        await expectLater(
          repository.saveZone(zone.copyWith(ratePerHour: rate), actor: _actor),
          throwsA(isA<ParkingRuleException>()),
        );
      }
    },
  );

  test('alert moves through monitoring and resolved with history', () async {
    final original = (await repository.fetchSnapshot()).alerts.singleWhere(
      (alert) => alert.id == 'AL-2001',
    );
    final monitoring = await repository.updateAlert(
      original.id,
      classification: 'Sensor offline',
      action: 'Checked the sensor',
      actionCompleted: false,
      actor: _actor,
    );
    expect(monitoring.status, AlertStatus.monitoring);
    expect(monitoring.history.length, original.history.length + 1);
    expect(monitoring.history.last.description, contains('Monitoring'));

    final resolved = await repository.updateAlert(
      original.id,
      classification: 'Sensor offline',
      action: 'Replaced the sensor',
      actionCompleted: true,
      actor: _actor,
    );
    expect(resolved.status, AlertStatus.resolved);
    expect(resolved.history.length, original.history.length + 2);
    expect(resolved.history.last.description, contains('Resolved'));
    final snapshot = await repository.fetchSnapshot();
    expect(snapshot.audit.length, 2);
    await expectLater(
      repository.updateAlert(
        original.id,
        classification: 'Sensor offline',
        action: 'Another action',
        actionCompleted: true,
        actor: _actor,
      ),
      throwsA(isA<ParkingRuleException>()),
    );
  });
}
