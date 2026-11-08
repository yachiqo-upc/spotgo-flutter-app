import 'guest_session.dart';
import 'operational_alert.dart';
import 'parking_spot.dart';
import 'parking_zone.dart';

class AuditEntry {
  const AuditEntry({
    required this.at,
    required this.actor,
    required this.action,
    required this.before,
    required this.after,
  });

  final DateTime at;
  final String actor;
  final String action;
  final String before;
  final String after;
}

/// Operational state of the facility managed by the signed in admin.
class ParkingSnapshot {
  const ParkingSnapshot({
    required this.facilityName,
    required this.district,
    required this.zones,
    required this.spots,
    required this.alerts,
    required this.guestSessions,
    required this.outstandingBalances,
    required this.audit,
    required this.updatedAt,
  });

  final String facilityName;
  final String district;
  final List<ParkingZone> zones;
  final List<ParkingSpot> spots;
  final List<OperationalAlert> alerts;
  final List<GuestSession> guestSessions;

  /// Driver operations with pending balance, owned by Payments & Billing.
  final int outstandingBalances;
  final List<AuditEntry> audit;
  final DateTime updatedAt;
}
