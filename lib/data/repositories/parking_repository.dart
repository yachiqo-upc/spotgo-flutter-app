import '../models/guest_session.dart';
import '../models/operational_alert.dart';
import '../models/parking_snapshot.dart';
import '../models/parking_zone.dart';

class GuestSessionDraft {
  const GuestSessionDraft({
    required this.plate,
    required this.vehicleType,
    required this.spotId,
    required this.expectedDuration,
    this.color,
  });

  final String plate;
  final VehicleType vehicleType;
  final String? color;
  final String spotId;
  final Duration expectedDuration;
}

/// Contract for Parking Infrastructure and Occupancy & Monitoring services.
/// Mutations throw `ParkingRuleException` when a business rule rejects them.
abstract interface class ParkingRepository {
  Future<ParkingSnapshot> fetchSnapshot();

  Future<ParkingZone> saveZone(ParkingZone zone, {required String actor});

  Future<GuestSession> startGuestSession(
    GuestSessionDraft draft, {
    required String actor,
  });

  Future<GuestSession> registerGuestExit(
    String sessionId, {
    required String actor,
  });

  Future<GuestSession> confirmGuestPayment(
    String sessionId, {
    required PhysicalPaymentMethod method,
    String? reference,
    required String actor,
  });

  Future<OperationalAlert> updateAlert(
    String alertId, {
    required String classification,
    required String action,
    required bool actionCompleted,
    required String actor,
  });
}
