import 'dart:async';
import 'dart:io';

import '../../core/api/role_guard.dart';
import '../../core/utils/evidence_image.dart';
import '../models/monitoring.dart';
import '../repositories/monitoring_repository.dart';
import 'spotgo_api.dart';

class RemoteMonitoringRepository implements MonitoringRepository {
  RemoteMonitoringRepository(this.api);
  final SpotGoApi api;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException catch (error) {
      throw MonitoringException(error.message, status: error.status);
    } on RoleGuardException catch (error) {
      throw MonitoringException(error.message, status: 403);
    } on SocketException catch (error) {
      throw MonitoringException(
        'Could not reach the monitoring service: ${error.message}',
      );
    } on TimeoutException {
      throw const MonitoringException(
        'The monitoring service did not respond in time.',
      );
    } on HttpException catch (error) {
      throw MonitoringException('Monitoring network error: ${error.message}');
    } on FormatException catch (error) {
      throw MonitoringException(
        'Invalid monitoring response: ${error.message}',
      );
    }
  }

  Future<List<T>> _list<T>(String path, T Function(Json) parse) =>
      _guard(() async => (await api.list(path)).map(parse).toList());

  Future<T> _object<T>(
    String path,
    T Function(Json) parse, {
    String method = 'GET',
    Json? body,
  }) => _guard(
    () async => parse(await api.object(path, method: method, body: body)),
  );

  @override
  Future<List<MonitoringSensor>> listSensors() =>
      _list('/occupancy-sensors', MonitoringSensor.fromJson);

  @override
  Future<MonitoringSensor> sensor(String sensorId) =>
      _object('/occupancy-sensors/$sensorId', MonitoringSensor.fromJson);

  @override
  Future<MonitoringSensor> registerSensor({
    required String spotId,
    required DateTime installedAt,
    required OccupancyValue firstOccupancy,
    required DateTime occurredAt,
    required double quality,
  }) => _object(
    '/occupancy-sensors',
    MonitoringSensor.fromJson,
    method: 'POST',
    body: {
      'spotId': spotId,
      'protocol': 'HTTP',
      'configuration': <String, dynamic>{},
      'installedAt': installedAt.toUtc().toIso8601String(),
      'firstReading': {
        'occupancyStatus': _occupancyWire(firstOccupancy),
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'quality': quality,
      },
    },
  );

  @override
  Future<MonitoringSensor> deactivateSensor(String sensorId) => _object(
    '/occupancy-sensors/$sensorId/deactivate',
    MonitoringSensor.fromJson,
    method: 'POST',
  );

  @override
  Future<SpotObservation> occupancyForSpot(String spotId) => _object(
    '/occupancy-sensors/spots/$spotId/occupancy',
    SpotObservation.fromJson,
  );

  @override
  Future<List<OccupancyReading>> readings(String sensorId) => _guard(
    () async => (await api.list('/occupancy-readings', {
      'sensorId': sensorId,
    })).map(OccupancyReading.fromJson).toList(),
  );

  @override
  Future<OccupancyReading> addReading({
    required String sensorId,
    required OccupancyValue occupancy,
    required DateTime occurredAt,
    required double quality,
  }) => _object(
    '/occupancy-readings',
    OccupancyReading.fromJson,
    method: 'POST',
    body: {
      'sensorId': sensorId,
      'occupancyStatus': _occupancyWire(occupancy),
      'occurredAt': occurredAt.toUtc().toIso8601String(),
      'quality': quality,
    },
  );

  @override
  Future<List<SensorHealthEvent>> healthEvents(String sensorId) => _guard(
    () async => (await api.list('/sensor-health-events', {
      'sensorId': sensorId,
    })).map(SensorHealthEvent.fromJson).toList(),
  );

  @override
  Future<SensorHealthEvent> healthEvent(String healthEventId) => _object(
    '/sensor-health-events/$healthEventId',
    SensorHealthEvent.fromJson,
  );

  @override
  Future<SensorHealthEvent> addHealthEvent({
    required String sensorId,
    required SensorHealth health,
    required String reason,
  }) => _object(
    '/sensor-health-events',
    SensorHealthEvent.fromJson,
    method: 'POST',
    body: {
      'sensorId': sensorId,
      'health': _healthWire(health),
      'reason': reason,
    },
  );

  @override
  Future<SensorHealthEvent> recoverHealthEvent(String healthEventId) => _object(
    '/sensor-health-events/$healthEventId/recover',
    SensorHealthEvent.fromJson,
    method: 'POST',
  );

  @override
  Future<List<OccupancyConflict>> conflicts() =>
      _list('/occupancy-conflicts', OccupancyConflict.fromJson);

  @override
  Future<OccupancyConflict> conflict(String conflictId) =>
      _object('/occupancy-conflicts/$conflictId', OccupancyConflict.fromJson);

  @override
  Future<OccupancyConflict> acknowledgeConflict(String conflictId) => _object(
    '/occupancy-conflicts/$conflictId/acknowledge',
    OccupancyConflict.fromJson,
    method: 'POST',
  );

  @override
  Future<OccupancyConflict> resolveConflict(String conflictId) => _object(
    '/occupancy-conflicts/$conflictId/resolve',
    OccupancyConflict.fromJson,
    method: 'POST',
  );

  @override
  Future<List<OccupancyAlert>> alerts() =>
      _list('/occupancy-alerts', OccupancyAlert.fromJson);

  @override
  Future<OccupancyAlert> acknowledgeAlert(String alertId) => _object(
    '/occupancy-alerts/$alertId/acknowledge',
    OccupancyAlert.fromJson,
    method: 'POST',
  );

  @override
  Future<OccupancyAlert> closeAlert({
    required String alertId,
    required ResolutionClassification classification,
    required String action,
  }) => _object(
    '/occupancy-alerts/$alertId/close',
    OccupancyAlert.fromJson,
    method: 'POST',
    body: {
      'resolutionClassification': _resolutionWire(classification),
      'resolutionAction': action,
    },
  );

  @override
  Future<void> uploadEvidence({
    required String alertId,
    required List<int> bytes,
    required String contentType,
  }) => _guard(() async {
    final validationError = validateEvidenceImage(bytes, contentType);
    if (validationError != null) {
      throw MonitoringException(validationError);
    }
    await api.uploadImage(
      '/occupancy-alerts/$alertId/evidence',
      bytes: bytes,
      contentType: contentType,
    );
  });

  @override
  Future<List<int>> evidence(String alertId) =>
      _guard(() => api.bytes('/occupancy-alerts/$alertId/evidence'));

  @override
  Future<List<CapacitySnapshot>> capacitySnapshots() =>
      _list('/capacity-snapshots', CapacitySnapshot.fromJson);

  @override
  Future<CapacitySnapshot> createCapacitySnapshot({String? zoneId}) async {
    final tenantId = api.authenticatedTenantId;
    if (tenantId is! String || tenantId.isEmpty) {
      throw const MonitoringException('Your session has ended. Sign in again.');
    }
    return _object(
      '/capacity-snapshots',
      CapacitySnapshot.fromJson,
      method: 'POST',
      body: {'tenantId': tenantId, 'zoneId': zoneId},
    );
  }

  @override
  Future<List<CapacityAlert>> capacityAlerts() =>
      _list('/capacity-alerts', CapacityAlert.fromJson);

  @override
  Future<CapacityAlert> acknowledgeCapacityAlert(String alertId) => _object(
    '/capacity-alerts/$alertId/acknowledge',
    CapacityAlert.fromJson,
    method: 'POST',
  );

  @override
  Future<List<OccupancyReport>> reports() =>
      _list('/occupancy-reports', OccupancyReport.fromJson);

  @override
  Future<OccupancyReport> createReport({
    required String zoneId,
    required DateTime intervalStart,
    required DateTime intervalEnd,
  }) {
    final now = DateTime.now();
    if (!intervalEnd.isAfter(intervalStart) ||
        intervalEnd.difference(intervalStart) > const Duration(days: 366) ||
        intervalEnd.isAfter(now)) {
      throw const MonitoringException(
        'Choose a past interval of 366 days or less with an end after its start.',
      );
    }
    return _object(
      '/occupancy-reports',
      OccupancyReport.fromJson,
      method: 'POST',
      body: {
        'zoneId': zoneId,
        'intervalStart': intervalStart.toUtc().toIso8601String(),
        'intervalEnd': intervalEnd.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<ParkingMapLayout?> getPublishedMap(String zoneId) async => null;
}

String _occupancyWire(OccupancyValue value) => switch (value) {
  OccupancyValue.available => 'AVAILABLE',
  OccupancyValue.occupied => 'OCCUPIED',
  _ => throw const MonitoringException(
    'A first reading must be AVAILABLE or OCCUPIED.',
  ),
};

String _healthWire(SensorHealth value) => switch (value) {
  SensorHealth.healthy => 'HEALTHY',
  SensorHealth.degraded => 'DEGRADED',
  SensorHealth.failed => 'FAILED',
  SensorHealth.unknown => 'UNKNOWN',
};

String _resolutionWire(ResolutionClassification value) => switch (value) {
  ResolutionClassification.unauthorizedOccupancy => 'UNAUTHORIZED_OCCUPANCY',
  ResolutionClassification.reservationReassigned => 'RESERVATION_REASSIGNED',
  ResolutionClassification.sensorRecovered => 'SENSOR_RECOVERED',
  ResolutionClassification.falsePositive => 'FALSE_POSITIVE',
  ResolutionClassification.other => 'OTHER',
  ResolutionClassification.unknown => throw const MonitoringException(
    'Choose a resolution classification.',
  ),
};
