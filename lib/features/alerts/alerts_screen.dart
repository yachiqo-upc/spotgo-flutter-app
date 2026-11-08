import 'package:flutter/material.dart';

import '../../app/admin_navigation.dart';
import '../../app/app_scope.dart';
import '../../core/widgets/choice_chip_bar.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/operational_alert.dart';
import '../../state/admin_controller.dart';
import '../shell/account_sheet.dart';
import 'alert_detail_screen.dart';
import 'alert_widgets.dart';

enum _AlertFilter { all, critical, sensor, payment, resolved }

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  _AlertFilter _filter = _AlertFilter.all;

  List<OperationalAlert> _visibleAlerts(AdminController admin) {
    if (_filter == _AlertFilter.resolved) {
      return admin.alerts
          .where((alert) => alert.status == AlertStatus.resolved)
          .toList();
    }
    final pending = admin.pendingAlerts;
    return switch (_filter) {
      _AlertFilter.all => pending,
      _AlertFilter.critical =>
        pending.where((alert) => alert.isCritical).toList(),
      _AlertFilter.sensor =>
        pending
            .where((alert) => alert.type.category == AlertCategory.sensor)
            .toList(),
      _AlertFilter.payment =>
        pending
            .where((alert) => alert.type.category == AlertCategory.payment)
            .toList(),
      _AlertFilter.resolved => const <OperationalAlert>[],
    };
  }

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    if (!admin.hasData) {
      if (admin.error != null) {
        return ErrorView(message: admin.error!, onRetry: admin.load);
      }
      return const LoadingView(message: 'Loading alerts...');
    }

    final alerts = _visibleAlerts(admin);
    return RefreshIndicator(
      onRefresh: admin.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenHeader(
                  title: 'Operational alerts',
                  subtitle: 'Sensor, occupancy, payment and reservation issues',
                  onProfileTap: () => showAccountSheet(context),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in _AlertFilter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChipBar<_AlertFilter>(
                            key: Key('alert-filter-${filter.name}'),
                            options: [ChipOption(filter, _label(filter))],
                            selected: _filter,
                            onSelected: (value) =>
                                setState(() => _filter = value),
                          ),
                        ),
                    ],
                  ),
                ),
                if (admin.error != null) ...[
                  const SizedBox(height: 12),
                  NoticeCard(message: admin.error!, icon: Icons.info_outline),
                ],
                const SizedBox(height: 16),
                if (alerts.isEmpty)
                  const EmptyView(
                    title: 'No alerts in this filter',
                    message: 'Pull down to check for new operational alerts.',
                    icon: Icons.notifications_none,
                  )
                else
                  for (final alert in alerts) ...[
                    AlertCard(
                      key: Key('alert-card-${alert.id}'),
                      alert: alert,
                      now: admin.now,
                      onTap: () {
                        pushAdminPage<void>(
                          context,
                          AlertDetailScreen(alertId: alert.id),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _label(_AlertFilter filter) => switch (filter) {
    _AlertFilter.all => 'All',
    _AlertFilter.critical => 'Critical',
    _AlertFilter.sensor => 'Sensor',
    _AlertFilter.payment => 'Payment',
    _AlertFilter.resolved => 'Resolved',
  };
}
