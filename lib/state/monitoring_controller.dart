import 'package:flutter/foundation.dart';

import '../data/models/monitoring.dart';
import '../data/repositories/monitoring_repository.dart';

enum MonitoringPhase { idle, loading, success, error }

class MonitoringController extends ChangeNotifier {
  MonitoringController({
    required this.repository,
    this.debugReadingWritesEnabled = false,
  });

  final MonitoringRepository repository;
  MonitoringRepository get _repository => repository;
  final bool debugReadingWritesEnabled;
  bool _loading = false;
  bool _loaded = false;
  bool _forbidden = false;
  String? _error;
  int? _errorStatus;
  List<MonitoringSensor> _sensors = const [];
  List<OccupancyConflict> _conflicts = const [];
  List<OccupancyAlert> _alerts = const [];
  List<CapacitySnapshot> _snapshots = const [];
  List<CapacityAlert> _capacityAlerts = const [];
  final Map<String, SpotObservation> _observations = {};
  final Map<String, List<OccupancyReading>> _readings = {};
  final Map<String, List<SensorHealthEvent>> _healthEvents = {};
  final Map<String, Uint8List> _evidence = {};

  bool get loading => _loading;
  bool get loaded => _loaded;
  bool get forbidden => _forbidden;
  String? get error => _error;
  int? get errorStatus => _errorStatus;
  MonitoringPhase get phase => _loading
      ? MonitoringPhase.loading
      : _error != null
      ? MonitoringPhase.error
      : _loaded
      ? MonitoringPhase.success
      : MonitoringPhase.idle;
  List<MonitoringSensor> get sensors => _sensors;
  List<OccupancyConflict> get conflicts => _conflicts;
  List<OccupancyAlert> get alerts => _alerts;
  List<CapacitySnapshot> get snapshots => _snapshots;
  List<CapacityAlert> get capacityAlerts => _capacityAlerts;
  Map<String, SpotObservation> get observations =>
      Map.unmodifiable(_observations);

  MonitoringSensor? sensorForSpot(String spotId) => _sensors
      .where(
        (sensor) =>
            sensor.spotId == spotId && sensor.status == SensorStatus.active,
      )
      .firstOrNull;

  Future<void> load() async {
    if (_forbidden) return;
    _loading = true;
    _error = null;
    _errorStatus = null;
    _forbidden = false;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _repository.listSensors(),
        _repository.conflicts(),
        _repository.alerts(),
        _repository.capacitySnapshots(),
        _repository.capacityAlerts(),
      ]);
      _sensors = results[0] as List<MonitoringSensor>;
      _conflicts = results[1] as List<OccupancyConflict>;
      _alerts = results[2] as List<OccupancyAlert>;
      _snapshots = results[3] as List<CapacitySnapshot>;
      _capacityAlerts = results[4] as List<CapacityAlert>;
      _loaded = true;
    } on MonitoringException catch (error) {
      _setError(error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_forbidden) return;
    _loading = true;
    notifyListeners();
    try {
      await _refresh();
      _error = null;
      _errorStatus = null;
      _forbidden = false;
      _loaded = true;
    } on MonitoringException catch (error) {
      _setError(error);
    } finally {
      _loading = false;
    }
    notifyListeners();
  }

  Future<void> _refresh() async {
    final results = await Future.wait<Object>([
      _repository.listSensors(),
      _repository.conflicts(),
      _repository.alerts(),
      _repository.capacitySnapshots(),
      _repository.capacityAlerts(),
    ]);
    _sensors = results[0] as List<MonitoringSensor>;
    _conflicts = results[1] as List<OccupancyConflict>;
    _alerts = results[2] as List<OccupancyAlert>;
    _snapshots = results[3] as List<CapacitySnapshot>;
    _capacityAlerts = results[4] as List<CapacityAlert>;
  }

  Future<SpotObservation> occupancyForSpot(String spotId) => _run(() async {
    final observation = await _repository.occupancyForSpot(spotId);
    _observations[spotId] = observation;
    return observation;
  });

  Future<MonitoringSensor> sensor(String sensorId) =>
      _run(() => _repository.sensor(sensorId));

  Future<MonitoringSensor> registerSensor({
    required String spotId,
    required DateTime installedAt,
    required OccupancyValue firstOccupancy,
    required DateTime occurredAt,
    required double quality,
  }) {
    final now = DateTime.now();
    if (installedAt.isAtSameMomentAs(occurredAt) ||
        installedAt.isAfter(occurredAt) ||
        occurredAt.isAfter(now) ||
        quality < 0 ||
        quality > 100 ||
        (firstOccupancy != OccupancyValue.available &&
            firstOccupancy != OccupancyValue.occupied)) {
      throw const MonitoringException(
        'Use an installation time before a valid first reading with quality from 0 to 100.',
      );
    }
    return _mutate(
      () => _repository.registerSensor(
        spotId: spotId,
        installedAt: installedAt,
        firstOccupancy: firstOccupancy,
        occurredAt: occurredAt,
        quality: quality,
      ),
    );
  }

  Future<MonitoringSensor> deactivateSensor(String sensorId) =>
      _mutate(() => _repository.deactivateSensor(sensorId));

  Future<List<OccupancyReading>> readings(String sensorId) => _run(() async {
    final items = await _repository.readings(sensorId);
    _readings[sensorId] = items;
    return items;
  });

  Future<OccupancyReading> addReading({
    required String sensorId,
    required OccupancyValue occupancy,
    required DateTime occurredAt,
    required double quality,
  }) {
    if (!kDebugMode || !debugReadingWritesEnabled) {
      throw const MonitoringException(
        'Reading submissions are available only when explicitly enabled for debugging.',
      );
    }
    return _run(
      () => _repository.addReading(
        sensorId: sensorId,
        occupancy: occupancy,
        occurredAt: occurredAt,
        quality: quality,
      ),
    );
  }

  Future<List<SensorHealthEvent>> healthEvents(String sensorId) =>
      _run(() async {
        final items = await _repository.healthEvents(sensorId);
        _healthEvents[sensorId] = items;
        return items;
      });

  Future<SensorHealthEvent> addHealthEvent({
    required String sensorId,
    required SensorHealth health,
    required String reason,
  }) {
    if (reason.trim().isEmpty || reason.trim().length > 255) {
      throw const MonitoringException(
        'Health reason is required and must be at most 255 characters.',
      );
    }
    return _run(
      () => _repository.addHealthEvent(
        sensorId: sensorId,
        health: health,
        reason: reason.trim(),
      ),
    );
  }

  Future<SensorHealthEvent> healthEvent(String healthEventId) =>
      _run(() => _repository.healthEvent(healthEventId));

  Future<SensorHealthEvent> recoverHealthEvent(String healthEventId) =>
      _run(() => _repository.recoverHealthEvent(healthEventId));

  Future<OccupancyConflict> acknowledgeConflict(String id) =>
      _replaceConflict(() => _repository.acknowledgeConflict(id));

  Future<OccupancyConflict> resolveConflict(String id) =>
      _replaceConflict(() => _repository.resolveConflict(id));

  Future<OccupancyConflict> conflict(String id) =>
      _run(() => _repository.conflict(id));

  Future<OccupancyAlert> acknowledgeAlert(String id) =>
      _replaceAlert(() => _repository.acknowledgeAlert(id));

  Future<OccupancyAlert> closeAlert({
    required String alertId,
    required ResolutionClassification classification,
    required String action,
  }) => _run(() async {
    if (action.trim().isEmpty || action.trim().length > 1000) {
      throw const MonitoringException(
        'Resolution action is required and must be at most 1000 characters.',
      );
    }
    final alert = _alerts.where((item) => item.alertId == alertId).firstOrNull;
    if (alert?.conflictId case final String conflictId) {
      final conflict = _conflicts
          .where((item) => item.conflictId == conflictId)
          .firstOrNull;
      if (conflict != null && conflict.status != MonitoringStatus.resolved) {
        final resolved = await _repository.resolveConflict(conflictId);
        _setConflict(resolved);
      }
    }
    final updated = await _repository.closeAlert(
      alertId: alertId,
      classification: classification,
      action: action.trim(),
    );
    _setAlert(updated);
    notifyListeners();
    return updated;
  });

  Future<void> uploadEvidence({
    required String alertId,
    required List<int> bytes,
    required String contentType,
  }) => _run(() async {
    await _repository.uploadEvidence(
      alertId: alertId,
      bytes: bytes,
      contentType: contentType,
    );
    _evidence.remove(alertId);
    notifyListeners();
  });

  Future<Uint8List> evidence(String alertId) => _run(() async {
    final cached = _evidence[alertId];
    if (cached != null) return cached;
    final bytes = Uint8List.fromList(await _repository.evidence(alertId));
    _evidence[alertId] = bytes;
    return bytes;
  });

  Uint8List? cachedEvidence(String alertId) => _evidence[alertId];

  Future<CapacitySnapshot> createCapacitySnapshot({String? zoneId}) => _run(
    () async {
      final snapshot = await _repository.createCapacitySnapshot(zoneId: zoneId);
      _snapshots = [snapshot, ..._snapshots];
      notifyListeners();
      return snapshot;
    },
  );

  Future<CapacityAlert> acknowledgeCapacityAlert(String id) => _run(() async {
    final alert = await _repository.acknowledgeCapacityAlert(id);
    _capacityAlerts = [
      for (final item in _capacityAlerts)
        item.capacityAlertId == id ? alert : item,
    ];
    notifyListeners();
    return alert;
  });

  Future<ParkingMapLayout?> getPublishedMap(String zoneId) =>
      _run(() => _repository.getPublishedMap(zoneId));

  void clearError() {
    _error = null;
    _errorStatus = null;
    _forbidden = false;
    notifyListeners();
  }

  Future<T> _mutate<T>(Future<T> Function() action) => _run(() async {
    final result = await action();
    await _refresh();
    notifyListeners();
    return result;
  });

  Future<T> _replaceConflict<T extends OccupancyConflict>(
    Future<T> Function() action,
  ) => _run(() async {
    final conflict = await action();
    _setConflict(conflict);
    notifyListeners();
    return conflict;
  });

  Future<T> _replaceAlert<T extends OccupancyAlert>(
    Future<T> Function() action,
  ) => _run(() async {
    final alert = await action();
    _setAlert(alert);
    notifyListeners();
    return alert;
  });

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      _error = null;
      _errorStatus = null;
      _forbidden = false;
      return await action();
    } on MonitoringException catch (error) {
      _setError(error);
      notifyListeners();
      rethrow;
    }
  }

  void _setError(MonitoringException error) {
    _error = error.message;
    _forbidden = error.status == 403;
    _errorStatus = error.status;
  }

  void _setConflict(OccupancyConflict conflict) {
    _conflicts = [
      for (final item in _conflicts)
        item.conflictId == conflict.conflictId ? conflict : item,
    ];
  }

  void _setAlert(OccupancyAlert alert) {
    _alerts = [
      for (final item in _alerts) item.alertId == alert.alertId ? alert : item,
    ];
  }
}
