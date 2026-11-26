import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/monitoring.dart';
import '../../data/models/parking_zone.dart';
import '../../data/repositories/monitoring_repository.dart';
import '../../state/admin_controller.dart';
import '../../state/reports_controller.dart';
import '../shell/account_sheet.dart';

enum _Range { today, week, month }

class OccupancyReportsScreen extends StatefulWidget {
  const OccupancyReportsScreen({super.key});

  @override
  State<OccupancyReportsScreen> createState() => _OccupancyReportsScreenState();
}

class _OccupancyReportsScreenState extends State<OccupancyReportsScreen> {
  _Range _range = _Range.today;
  String? _zoneId;
  bool _requested = false;
  bool _creating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    final controller = AppScope.of(context).reports;
    if (!controller.loaded && !controller.loading) controller.load();
  }

  DateTime _start(DateTime now) {
    return switch (_range) {
      _Range.today => DateTime(now.year, now.month, now.day),
      _Range.week => now.subtract(const Duration(days: 7)),
      _Range.month => now.subtract(const Duration(days: 30)),
    };
  }

  Future<void> _generate(
    ReportsController controller,
    AdminController admin,
  ) async {
    final zoneId = _zoneId ?? admin.zones.firstOrNull?.id;
    if (zoneId == null) return;
    setState(() => _creating = true);
    try {
      final now = DateTime.now();
      await controller.createReport(
        zoneId: zoneId,
        intervalStart: _start(now),
        intervalEnd: now,
      );
    } on MonitoringException {
      // The controller retains the backend or validation message for display.
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _refresh(ReportsController controller) => controller.refresh();

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final controller = AppScope.of(context).reports;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.forbidden) {
          return ErrorView(
            message: '${controller.error ?? 'Access denied.'} (HTTP 403)',
          );
        }
        return RefreshIndicator(
          onRefresh: () => _refresh(controller),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              PageContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ScreenHeader(
                      title: 'Occupancy reports',
                      subtitle: 'Operational trends for ${admin.facilityName}',
                      onProfileTap: () => showAccountSheet(context),
                      onBack: Navigator.of(context).canPop()
                          ? () => Navigator.of(context).maybePop()
                          : null,
                    ),
                    if (controller.error != null)
                      Card(
                        child: ListTile(
                          title: Text(
                            '${controller.error}'
                            '${controller.errorStatus == null ? '' : ' (HTTP ${controller.errorStatus})'}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Retry',
                            onPressed: controller.loading
                                ? null
                                : () => _refresh(controller),
                            icon: const Icon(Icons.refresh),
                          ),
                        ),
                      ),
                    DropdownButtonFormField<String>(
                      initialValue:
                          admin.zones.any((zone) => zone.id == _zoneId)
                          ? _zoneId
                          : admin.zones.firstOrNull?.id,
                      decoration: const InputDecoration(labelText: 'Zone'),
                      items: [
                        for (final zone in admin.zones)
                          DropdownMenuItem(
                            value: zone.id,
                            child: Text(zone.name),
                          ),
                      ],
                      onChanged: (value) => setState(() => _zoneId = value),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final range in _Range.values)
                          ChoiceChip(
                            label: Text(switch (range) {
                              _Range.today => 'Today',
                              _Range.week => '7 days',
                              _Range.month => '30 days',
                            }),
                            selected: _range == range,
                            onSelected: (_) => setState(() => _range = range),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_start(DateTime.now()).toLocal()} – ${DateTime.now().toLocal()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: admin.zones.isEmpty || _creating
                          ? null
                          : () => _generate(controller, admin),
                      icon: _creating
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.assessment_outlined),
                      label: const Text('Generate report'),
                    ),
                    const SizedBox(height: 16),
                    if (admin.zones.isEmpty)
                      const Card(
                        child: EmptyView(
                          title: 'No parking zones',
                          message: 'A zone is required to generate a report.',
                        ),
                      )
                    else if (controller.loading && controller.reports.isEmpty)
                      const Card(
                        child: LoadingView(message: 'Loading reports...'),
                      )
                    else if (controller.reports.isEmpty)
                      const Card(
                        child: EmptyView(
                          title: 'No occupancy reports yet',
                          message: 'Generate a report for the selected zone and range.',
                        ),
                      )
                    else
                      for (final report in controller.reports) ...[
                        _ReportCard(
                          report: report,
                          zone: admin.zoneById(report.zoneId),
                        ),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.zone});

  final OccupancyReport report;
  final ParkingZone? zone;

  @override
  Widget build(BuildContext context) {
    final totals = report.totals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              zone?.name ?? report.zoneId,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${report.intervalStart?.toLocal() ?? '—'} – ${report.intervalEnd?.toLocal() ?? '—'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (report.isEmptyOrZero)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: NoticeCard(
                  icon: Icons.info_outline,
                  message: 'This report contains no recorded activity.',
                ),
              )
            else
              for (final entry in totals)
                InfoRow(title: entry.key, trailing: '${entry.value}'),
          ],
        ),
      ),
    );
  }
}
