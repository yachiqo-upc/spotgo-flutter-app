import 'package:flutter/material.dart';

import '../../app/admin_navigation.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/page_layout.dart';
import '../access/spot_access_screen.dart';
import '../billing/billing_screen.dart';
import '../guests/guest_sessions_screen.dart';
import '../map/digital_parking_map_screen.dart';
import '../map/upload_floor_plan_screen.dart';
import '../reports/occupancy_reports_screen.dart';
import '../zones/parking_zones_screen.dart';
import 'account_sheet.dart';
import 'admin_shell.dart';
import 'audit_history_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    const chevron = Icon(Icons.chevron_right, color: AppColors.textSecondary);

    return SingleChildScrollView(
      child: PageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: 'More',
              subtitle: '${admin.facilityName} · zone management and records',
              onProfileTap: () => showAccountSheet(context),
            ),
            SectionCard(
              children: [
                InfoRow(
                  key: const Key('more-zones'),
                  title: 'My parking zones',
                  subtitle:
                      '${admin.zones.length} zones · ${admin.totalSpots} spots',
                  trailingWidget: chevron,
                  onTap: () => Navigator.of(context).push(
                    AdminShellState.moreSectionRoute(
                      const ParkingZonesScreen(),
                    ),
                  ),
                ),
                InfoRow(
                  key: const Key('more-guests'),
                  title: 'Guest parking sessions',
                  subtitle: '${admin.openGuestSessions} open sessions',
                  trailingWidget: chevron,
                  onTap: () => Navigator.of(context).push(
                    AdminShellState.moreSectionRoute(
                      const GuestSessionsScreen(),
                    ),
                  ),
                ),
                InfoRow(
                  key: const Key('more-reports'),
                  title: 'Occupancy reports',
                  subtitle: 'Operational trends for ${admin.facilityName}',
                  trailingWidget: chevron,
                  onTap: () => Navigator.of(context).push(
                    AdminShellState.moreSectionRoute(
                      const OccupancyReportsScreen(),
                    ),
                  ),
                ),
                InfoRow(
                  key: const Key('more-map'),
                  title: 'Digital parking map',
                  subtitle: 'Assign types and sensors before publishing',
                  trailingWidget: chevron,
                  onTap: () => Navigator.of(context).push(
                    AdminShellState.moreSectionRoute(
                      const DigitalParkingMapScreen(),
                    ),
                  ),
                ),
                InfoRow(
                  key: const Key('more-floor-plan'),
                  title: 'Upload floor plan',
                  subtitle: 'Add or replace a floor plan',
                  trailingWidget: chevron,
                  onTap: () => Navigator.of(context).push(
                    AdminShellState.moreSectionRoute(
                      const UploadFloorPlanScreen(),
                    ),
                  ),
                ),
                InfoRow(
                  key: const Key('more-access'),
                  title: 'Spot access & permissions',
                  subtitle: 'Spot groups, drivers and rules',
                  trailingWidget: chevron,
                  onTap: () => Navigator.of(context).push(
                    AdminShellState.moreSectionRoute(
                      const SpotAccessScreen(),
                    ),
                  ),
                ),
                InfoRow(
                  key: const Key('more-billing'),
                  title: 'Billing & invoices',
                  subtitle: 'Business account · plan and invoices',
                  trailingWidget: chevron,
                  onTap: () => Navigator.of(context).push(
                    AdminShellState.moreSectionRoute(const BillingScreen()),
                  ),
                ),
                InfoRow(
                  key: const Key('more-audit'),
                  title: 'Audit history',
                  subtitle: '${admin.audit.length} administrative changes',
                  trailingWidget: chevron,
                  onTap: () =>
                      pushAdminPage<void>(context, const AuditHistoryScreen()),
                ),
                InfoRow(
                  title: 'Account',
                  subtitle: 'Profile and sign out',
                  trailingWidget: chevron,
                  onTap: () => showAccountSheet(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
