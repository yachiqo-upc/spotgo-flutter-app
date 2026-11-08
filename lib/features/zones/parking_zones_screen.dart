import 'package:flutter/material.dart';

import '../../app/admin_navigation.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/parking_spot.dart';
import '../../data/models/parking_zone.dart';
import '../shell/account_sheet.dart';
import 'zone_form_screen.dart';

String formatMinutesOfDay(int minutes) =>
    Formatters.time(DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60));

/// Parking zones of the assigned facility (mockup 19, US02).
class ParkingZonesScreen extends StatelessWidget {
  const ParkingZonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final free = admin.countBy(SpotAvailability.available);
    final activeZones = admin.zones.where((z) => z.isActive).length;

    return SingleChildScrollView(
      child: PageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: 'My parking zones',
              subtitle: 'Manage your assigned zones, spots and operating rules',
              onProfileTap: () => showAccountSheet(context),
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).maybePop()
                  : null,
            ),
            SectionCard(
              children: [
                InfoRow(
                  title: admin.facilityName,
                  subtitle:
                      '${admin.district} · ${admin.totalSpots} spots · '
                      '$activeZones active zones',
                  trailing: '$free free',
                ),
              ],
            ),
            SectionTitle(
              'Zones',
              trailing: TextButton.icon(
                key: const Key('zone-new'),
                onPressed: () =>
                    pushAdminPage<void>(context, const ZoneFormScreen()),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New zone'),
              ),
            ),
            if (admin.zones.isEmpty)
              const Card(
                child: EmptyView(
                  icon: Icons.grid_view,
                  title: 'No zones configured',
                  message: 'Create a zone and assign its parking spots.',
                ),
              )
            else
              for (final zone in admin.zones) ...[
                _ZoneCard(zone: zone),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 6),
            NoticeCard(
              message:
                  'Your Administrator account is assigned to '
                  '${admin.facilityName}. Reservations follow each zone\'s '
                  'operating hours and changes are recorded in audit history.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({required this.zone});

  final ParkingZone zone;

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final spots = admin.spotsOfZone(zone.id);
    final free = spots
        .where((s) => s.availability == SpotAvailability.available)
        .length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('zone-card-${zone.id}'),
        onTap: () =>
            pushAdminPage<void>(context, ZoneFormScreen(zoneId: zone.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      zone.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  StatusBadge(
                    label: zone.status.label,
                    tone: zone.isActive ? BadgeTone.success : BadgeTone.danger,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${zone.district} · ${zone.totalSpots} spots · $free free',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${formatMinutesOfDay(zone.opensAtMinutes)} – '
                '${formatMinutesOfDay(zone.closesAtMinutes)} · '
                '${Formatters.money(zone.ratePerHour)}/h · '
                '${zone.billingFractionMinutes} min fraction',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      zone.allowedTypes.map((t) => t.label).join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const Text(
                    'Edit',
                    style: TextStyle(color: AppColors.primary, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
