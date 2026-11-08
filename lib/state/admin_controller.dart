import 'package:flutter/foundation.dart';

import '../data/models/admin_account.dart';
import '../data/models/guest_session.dart';
import '../data/models/operational_alert.dart';
import '../data/models/parking_snapshot.dart';
import '../data/models/parking_spot.dart';
import '../data/models/parking_zone.dart';
import '../data/repositories/parking_repository.dart';
import '../domain/parking_rules.dart';

/// Holds the operational state of the admin's facility and runs the use
/// cases through [ParkingRepository]. Screens listen through `AdminScope`.
class AdminController extends ChangeNotifier {
  AdminController({
    required ParkingRepository repository,
    required this.account,
    DateTime Function()? clock,
  }) : _repository = repository,
       _clock = clock ?? DateTime.now;

  final ParkingRepository _repository;
  final AdminAccount account;
  final DateTime Function() _clock;

  ParkingSnapshot? _snapshot;
  bool _loading = false;
  String? _error;
  bool _disposed = false;

  ParkingSnapshot? get snapshot => _snapshot;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasData => _snapshot != null;
  DateTime get now => _clock();

  List<ParkingZone> get zones => _snapshot?.zones ?? const [];
  List<ParkingSpot> get spots => _snapshot?.spots ?? const [];
  List<OperationalAlert> get alerts => _snapshot?.alerts ?? const [];
  List<GuestSession> get guestSessions => _snapshot?.guestSessions ?? const [];
  List<AuditEntry> get audit => _snapshot?.audit ?? const [];

  String get facilityName => _snapshot?.facilityName ?? account.facilityName;
  String get district => _snapshot?.district ?? account.district;

  // Dashboard indicators (US07).
  int get totalSpots => spots.length;
  int countBy(SpotAvailability availability) =>
      spots.where((s) => s.availability == availability).length;
  double get occupancyRatio => ParkingRules.occupancyRatio(spots);
  int get onlineSensors => spots.where((s) => s.sensorReliable).length;
  int get offlineSensors => totalSpots - onlineSensors;
  int get activeReservations =>
      spots.where((s) => s.reservation != ReservationState.none).length;
  int get openGuestSessions => guestSessions.where((s) => !s.isClosed).length;
  int get outstandingBalances => _snapshot?.outstandingBalances ?? 0;
  List<OperationalAlert> get pendingAlerts =>
      alerts.where((a) => a.isPending).toList();

  ParkingZone? zoneById(String id) =>
      zones.where((z) => z.id == id).firstOrNull;
  ParkingSpot? spotById(String id) =>
      spots.where((s) => s.id == id).firstOrNull;
  OperationalAlert? alertById(String id) =>
      alerts.where((a) => a.id == id).firstOrNull;
  GuestSession? sessionById(String id) =>
      guestSessions.where((s) => s.id == id).firstOrNull;

  List<ParkingSpot> spotsOfZone(String zoneId) =>
      spots.where((s) => s.zoneId == zoneId).toList();

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      _snapshot = await _repository.fetchSnapshot();
    } catch (_) {
      _error = 'Could not load the parking data. Check the connection and retry.';
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Reloads without hiding the current data (pull to refresh, live updates).
  Future<void> refresh() async {
    try {
      _snapshot = await _repository.fetchSnapshot();
      _error = null;
    } catch (_) {
      _error = 'Live update failed. Showing the last data received.';
    }
    _notify();
  }

  Future<ParkingZone> saveZone(ParkingZone zone) =>
      _mutate(() => _repository.saveZone(zone, actor: account.fullName));

  Future<GuestSession> startGuestSession(GuestSessionDraft draft) => _mutate(
    () => _repository.startGuestSession(draft, actor: account.fullName),
  );

  Future<GuestSession> registerGuestExit(String sessionId) => _mutate(
    () => _repository.registerGuestExit(sessionId, actor: account.fullName),
  );

  Future<GuestSession> confirmGuestPayment(
    String sessionId, {
    required PhysicalPaymentMethod method,
    String? reference,
  }) => _mutate(
    () => _repository.confirmGuestPayment(
      sessionId,
      method: method,
      reference: reference,
      actor: account.fullName,
    ),
  );

  Future<OperationalAlert> updateAlert(
    String alertId, {
    required String classification,
    required String action,
    required bool actionCompleted,
  }) => _mutate(
    () => _repository.updateAlert(
      alertId,
      classification: classification,
      action: action,
      actionCompleted: actionCompleted,
      actor: account.fullName,
    ),
  );

  /// Runs a mutation and refreshes the snapshot. Rule violations are
  /// rethrown as [ParkingRuleException] so forms can show them.
  Future<T> _mutate<T>(Future<T> Function() action) async {
    final result = await action();
    await refresh();
    return result;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
