import 'package:flutter/material.dart';

import '../../app/admin_navigation.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/operational_alert.dart';
import '../../data/models/parking_spot.dart';
import '../alerts/alert_detail_screen.dart';
import '../guests/guest_sessions_screen.dart';
import '../shell/account_sheet.dart';
import '../shell/admin_shell.dart';

/// Administrator dashboard (mockup 15, US07 scenario 1).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final shell = AdminShell.maybeOf(context);
    final occupied = admin.countBy(SpotAvailability.occupied);
    final available = admin.countBy(SpotAvailability.available);
    final reserved = admin.countBy(SpotAvailability.reserved);
    final sensorRatio = admin.totalSpots == 0
        ? 0.0
        : admin.onlineSensors / admin.totalSpots;
    final recentAlerts = admin.pendingAlerts.take(3).toList();

    return RefreshIndicator(
      onRefresh: admin.refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: PageContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                title: 'Administrator dashboard',
                subtitle:
                    '${admin.facilityName} · ${admin.district} · Live status',
                onProfileTap: () => showAccountSheet(context),
              ),
              if (admin.error != null) ...[
                NoticeCard(icon: Icons.sync_problem, message: admin.error!),
                const SizedBox(height: 12),
              ],
              MetricGrid(
                children: [
                  MetricCard(
                    key: const Key('metric-occupancy'),
                    value: Formatters.percent(admin.occupancyRatio),
                    label: 'Occupancy',
                    valueColor: AppColors.primary,
                    progress: admin.occupancyRatio,
                    onTap: () => shell?.selectTab(AdminTab.occupancy),
                  ),
                  MetricCard(
                    key: const Key('metric-available'),
                    value: '$available',
                    label: 'Available',
                    valueColor: AppColors.success,
                    onTap: () => shell?.selectTab(AdminTab.occupancy),
                  ),
                  MetricCard(
                    key: const Key('metric-alerts'),
                    value: '${admin.pendingAlerts.length}',
                    label: 'Open alerts',
                    valueColor: AppColors.warning,
                    onTap: () => shell?.selectTab(AdminTab.alerts),
                  ),
                  MetricCard(
                    key: const Key('metric-guests'),
                    value: '${admin.openGuestSessions}',
                    label: 'Guest sessions',
                    onTap: () =>
                        shell?.openMoreSection(const GuestSessionsScreen()),
                  ),
                  MetricCard(
                    value: '${admin.activeReservations}',
                    label: 'Active reservations',
                    valueColor: AppColors.warning,
                  ),
                  MetricCard(
                    value: '${admin.outstandingBalances}',
                    label: 'Outstanding balances',
                  ),
                ],
              ),
              const SectionTitle('My zone status'),
              SectionCard(
                children: [
                  InfoRow(
                    title: admin.facilityName,
                    subtitle: '$occupied occupied · $available available',
                    trailing: Formatters.percent(admin.occupancyRatio),
                  ),
                  InfoRow(
                    title: 'Reserved spots',
                    subtitle: '$reserved reserved · arrivals pending',
                    trailing: '$reserved',
                  ),
                  InfoRow(
                    title: 'Sensor health',
                    subtitle:
                        '${admin.onlineSensors} online · '
                        '${admin.offlineSensors} offline',
                    trailing: Formatters.percent(sensorRatio),
                  ),
                ],
              ),
              const SectionTitle('Availability by zone'),
              SectionCard(
                children: [
                  for (final zone in admin.zones)
                    Builder(
                      builder: (context) {
                        final zoneSpots = admin.spotsOfZone(zone.id);
                        final free = zoneSpots
                            .where(
                              (s) =>
                                  s.availability == SpotAvailability.available,
                            )
                            .length;
                        final busy = zoneSpots
                            .where(
                              (s) =>
                                  s.availability == SpotAvailability.occupied,
                            )
                            .length;
                        return InfoRow(
                          title: zone.name,
                          subtitle:
                              '$busy occupied · ${zoneSpots.length} spots · '
                              '${zone.status.label}',
                          trailing: '$free free',
                          onTap: () => shell?.selectTab(AdminTab.occupancy),
                        );
                      },
                    ),
                ],
              ),
              const SectionTitle('Recent alerts'),
              if (recentAlerts.isEmpty)
                const Card(
                  child: EmptyView(
                    icon: Icons.verified_outlined,
                    title: 'No pending alerts',
                  ),
                )
              else
                SectionCard(
                  children: [
                    for (final alert in recentAlerts)
                      InfoRow(
                        key: Key('recent-alert-${alert.id}'),
                        title: alert.title,
                        subtitle: alert.spotCode == null
                            ? admin.facilityName
                            : '${admin.facilityName} · Spot ${alert.spotCode}',
                        trailingWidget: Text(
                          alert.severity.label,
                          style: TextStyle(
                            color: _severityColor(alert.severity),
                            fontSize: 14,
                          ),
                        ),
                        onTap: () => pushAdminPage<void>(
                          context,
                          AlertDetailScreen(alertId: alert.id),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _severityColor(AlertSeverity severity) => switch (severity) {
    AlertSeverity.high => AppColors.danger,
    AlertSeverity.medium => AppColors.warning,
    AlertSeverity.info => AppColors.textSecondary,
  };
}

/// Two columns on phones, three on wider screens.
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const spacing = 10.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 3 : 2;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
