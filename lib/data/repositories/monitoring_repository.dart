import '../models/monitoring.dart';

class MonitoringException implements Exception {
  const MonitoringException(this.message, {this.status});
  final String message;
  final int? status;

  @override
  String toString() => message;
}

abstract interface class MonitoringRepository {
  Future<List<MonitoringSensor>> listSensors();
  Future<MonitoringSensor> sensor(String sensorId);
  Future<MonitoringSensor> registerSensor({
    required String spotId,
    required DateTime installedAt,
    required OccupancyValue firstOccupancy,
    required DateTime occurredAt,
    required double quality,
  });
  Future<MonitoringSensor> deactivateSensor(String sensorId);
  Future<SpotObservation> occupancyForSpot(String spotId);

  Future<List<OccupancyReading>> readings(String sensorId);
  Future<OccupancyReading> addReading({
    required String sensorId,
    required OccupancyValue occupancy,
    required DateTime occurredAt,
    required double quality,
  });
  Future<List<SensorHealthEvent>> healthEvents(String sensorId);
  Future<SensorHealthEvent> healthEvent(String healthEventId);
  Future<SensorHealthEvent> addHealthEvent({
    required String sensorId,
    required SensorHealth health,
    required String reason,
  });
  Future<SensorHealthEvent> recoverHealthEvent(String healthEventId);

  Future<List<OccupancyConflict>> conflicts();
  Future<OccupancyConflict> conflict(String conflictId);
  Future<OccupancyConflict> acknowledgeConflict(String conflictId);
  Future<OccupancyConflict> resolveConflict(String conflictId);
  Future<List<OccupancyAlert>> alerts();
  Future<OccupancyAlert> acknowledgeAlert(String alertId);
  Future<OccupancyAlert> closeAlert({
    required String alertId,
    required ResolutionClassification classification,
    required String action,
  });
  Future<void> uploadEvidence({
    required String alertId,
    required List<int> bytes,
    required String contentType,
  });
  Future<List<int>> evidence(String alertId);

  Future<List<CapacitySnapshot>> capacitySnapshots();
  Future<CapacitySnapshot> createCapacitySnapshot({String? zoneId});
  Future<List<CapacityAlert>> capacityAlerts();
  Future<CapacityAlert> acknowledgeCapacityAlert(String alertId);

  Future<List<OccupancyReport>> reports();
  Future<OccupancyReport> createReport({
    required String zoneId,
    required DateTime intervalStart,
    required DateTime intervalEnd,
  });
  Future<ParkingMapLayout?> getPublishedMap(String zoneId);
}
