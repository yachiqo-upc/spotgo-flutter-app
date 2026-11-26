import 'dart:async';
import 'dart:io';

import '../../core/api/role_guard.dart';
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
    if (bytes.length > 5 * 1024 * 1024) {
      throw const MonitoringException('Image must not exceed 5 MB.');
    }
    final isJpeg =
        contentType == 'image/jpeg' &&
        bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
    final isPng =
        contentType == 'image/png' &&
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47;
    if (!isJpeg && !isPng) {
      throw const MonitoringException('Choose a valid JPEG or PNG image.');
    }
    if (!_withinPixelLimit(bytes, png: isPng)) {
      throw const MonitoringException(
        'Evidence images must not exceed 20 million pixels.',
      );
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
    final tenantId = api.tenant?['tenantId'];
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

bool _withinPixelLimit(List<int> bytes, {required bool png}) {
  int? width;
  int? height;
  if (png) {
    if (bytes.length < 24 ||
        bytes[12] != 0x49 ||
        bytes[13] != 0x48 ||
        bytes[14] != 0x44 ||
        bytes[15] != 0x52) {
      return false;
    }
    width = _read32(bytes, 16);
    height = _read32(bytes, 20);
  } else {
    const frameMarkers = {
      0xc0,
      0xc1,
      0xc2,
      0xc3,
      0xc5,
      0xc6,
      0xc7,
      0xc9,
      0xca,
      0xcb,
      0xcd,
      0xce,
      0xcf,
    };
    var offset = 2;
    while (offset < bytes.length) {
      if (bytes[offset++] != 0xff) continue;
      while (offset < bytes.length && bytes[offset] == 0xff) {
        offset++;
      }
      if (offset >= bytes.length) return false;
      final marker = bytes[offset++];
      if (marker == 0xd8 ||
          marker == 0xd9 ||
          marker == 0x01 ||
          marker >= 0xd0 && marker <= 0xd7) {
        continue;
      }
      if (offset + 2 > bytes.length) return false;
      final segmentLength = bytes[offset] << 8 | bytes[offset + 1];
      if (segmentLength < 2 || offset + segmentLength > bytes.length) {
        return false;
      }
      if (frameMarkers.contains(marker)) {
        if (segmentLength < 7) return false;
        height = bytes[offset + 3] << 8 | bytes[offset + 4];
        width = bytes[offset + 5] << 8 | bytes[offset + 6];
        break;
      }
      offset += segmentLength;
    }
  }
  return width != null &&
      height != null &&
      width > 0 &&
      height > 0 &&
      width * height <= 20000000;
}

int _read32(List<int> bytes, int offset) =>
    bytes[offset] << 24 |
    bytes[offset + 1] << 16 |
    bytes[offset + 2] << 8 |
    bytes[offset + 3];
