import 'package:flutter/foundation.dart';

import '../data/models/monitoring.dart';
import '../data/repositories/monitoring_repository.dart';
import 'monitoring_controller.dart';

class ReportsController extends ChangeNotifier {
  ReportsController({required this.repository});

  final MonitoringRepository repository;
  List<OccupancyReport> _reports = const [];
  bool _loading = false;
  bool _loaded = false;
  bool _forbidden = false;
  String? _error;
  int? _errorStatus;

  List<OccupancyReport> get reports => _reports;
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

  Future<void> load() async {
    if (_forbidden) return;
    _loading = true;
    _clearError();
    notifyListeners();
    try {
      _reports = await repository.reports();
      _loaded = true;
    } on MonitoringException catch (error) {
      _setError(error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  Future<OccupancyReport> createReport({
    required String zoneId,
    required DateTime intervalStart,
    required DateTime intervalEnd,
  }) async {
    if (_forbidden) {
      throw MonitoringException(_error ?? 'Access denied.', status: 403);
    }
    _loading = true;
    _clearError();
    notifyListeners();
    try {
      final now = DateTime.now();
      if (!intervalEnd.isAfter(intervalStart) ||
          intervalEnd.difference(intervalStart) > const Duration(days: 366) ||
          intervalEnd.isAfter(now)) {
        throw const MonitoringException(
          'Choose a past interval of 366 days or less with an end after its start.',
          status: 400,
        );
      }
      final report = await repository.createReport(
        zoneId: zoneId,
        intervalStart: intervalStart,
        intervalEnd: intervalEnd,
      );
      _reports = [report, ..._reports];
      _loaded = true;
      return report;
    } on MonitoringException catch (error) {
      _setError(error);
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    _errorStatus = null;
    _forbidden = false;
  }

  void _setError(MonitoringException error) {
    _error = error.message;
    _errorStatus = error.status;
    _forbidden = error.status == 403;
  }
}
