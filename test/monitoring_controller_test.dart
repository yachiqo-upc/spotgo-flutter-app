import 'package:flutter_test/flutter_test.dart';
import 'package:spotgo_mobile_app/data/mock/mock_monitoring_repository.dart';
import 'package:spotgo_mobile_app/data/models/monitoring.dart';
import 'package:spotgo_mobile_app/state/monitoring_controller.dart';

void main() {
  test(
    'loads monitoring collections and handles a spot without a sensor',
    () async {
      final controller = MonitoringController(
        repository: MockMonitoringRepository(),
      );
      await controller.load();

      expect(controller.loaded, isTrue);
      expect(controller.sensors, isNotEmpty);
      expect(controller.conflicts, isNotEmpty);
      expect(controller.alerts, hasLength(2));
      final observation = await controller.occupancyForSpot('A-08');
      expect(observation.occupancy, OccupancyValue.unavailable);
      expect(observation.reason, 'NO_ACTIVE_SENSOR');
      controller.dispose();
    },
  );

  test('resolves a linked conflict before closing its alert', () async {
    final controller = MonitoringController(
      repository: MockMonitoringRepository(),
    );
    await controller.load();

    await controller.closeAlert(
      alertId: 'ALERT-1',
      classification: ResolutionClassification.other,
      action: 'Reviewed and resolved',
    );

    expect(
      controller.conflicts
          .singleWhere((item) => item.conflictId == 'CONFLICT-1')
          .status,
      MonitoringStatus.resolved,
    );
    expect(
      controller.alerts.singleWhere((item) => item.alertId == 'ALERT-1').status,
      MonitoringStatus.closed,
    );
    controller.dispose();
  });

  test('parses report totals dynamically and flags empty or zero reports', () {
    final now = DateTime.now();
    final empty = OccupancyReport.fromJson({
      'reportId': 'report-1',
      'zoneId': 'zone-1',
      'intervalStart': now.toUtc().toIso8601String(),
      'intervalEnd': now.toUtc().toIso8601String(),
      'totals': {
        'customMetric': {'count': 0},
      },
      'status': 'GENERATED',
    });

    expect(empty.totals.keys, contains('customMetric'));
    expect(empty.isEmptyOrZero, isTrue);
  });
}
