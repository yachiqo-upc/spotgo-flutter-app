import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/parking_spot.dart';

BadgeTone availabilityTone(ParkingSpot spot) {
  if (spot.hasUnvalidatedOccupancy) return BadgeTone.danger;
  return switch (spot.availability) {
    SpotAvailability.available => BadgeTone.success,
    SpotAvailability.reserved => BadgeTone.warning,
    SpotAvailability.occupied => BadgeTone.neutral,
    SpotAvailability.unavailable => BadgeTone.danger,
  };
}

class SpotLegend extends StatelessWidget {
  const SpotLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label, {Color? border}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: border == null ? null : Border.all(color: border),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        item(AppColors.spotAvailable, 'Available'),
        item(AppColors.spotOccupied, 'Occupied'),
        item(AppColors.spotReserved, 'Reserved'),
        item(
          AppColors.spotUnavailable,
          'Unavailable',
          border: AppColors.danger,
        ),
      ],
    );
  }
}

/// Zone block of the map: spot tiles split by a driving lane like mockup 16.
class ZoneSpotsCard extends StatelessWidget {
  const ZoneSpotsCard({
    super.key,
    required this.title,
    required this.totalSpots,
    required this.spots,
    required this.onSpotTap,
    this.showLane = true,
  });

  final String title;
  final int totalSpots;
  final List<ParkingSpot> spots;
  final ValueChanged<ParkingSpot> onSpotTap;
  final bool showLane;

  @override
  Widget build(BuildContext context) {
    final splitLane = showLane && spots.length > 4;
    final half = (spots.length / 2).ceil();
    final top = splitLane ? spots.sublist(0, half) : spots;
    final bottom = splitLane ? spots.sublist(half) : const <ParkingSpot>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '$totalSpots monitored spots',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SpotGrid(spots: top, onSpotTap: onSpotTap),
            if (splitLane) ...[
              const SizedBox(height: 10),
              const _DrivingLane(),
              const SizedBox(height: 10),
              _SpotGrid(spots: bottom, onSpotTap: onSpotTap),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpotGrid extends StatelessWidget {
  const _SpotGrid({required this.spots, required this.onSpotTap});

  final List<ParkingSpot> spots;
  final ValueChanged<ParkingSpot> onSpotTap;

  @override
  Widget build(BuildContext context) {
    const spacing = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 96).floor().clamp(3, 8).toInt();
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final spot in spots)
              SizedBox(
                width: width,
                child: SpotTile(spot: spot, onTap: () => onSpotTap(spot)),
              ),
          ],
        );
      },
    );
  }
}

class _DrivingLane extends StatelessWidget {
  const _DrivingLane();

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(color: AppColors.textMuted, fontSize: 10.5);
    return Column(
      children: [
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.spotOccupied.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: const Row(
            children: [
              Expanded(child: Divider(color: AppColors.textSecondary)),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Row(
          children: [
            Text('ENTRY', style: labelStyle),
            Spacer(),
            Text('EXIT', style: labelStyle),
          ],
        ),
      ],
    );
  }
}

class SpotTile extends StatelessWidget {
  const SpotTile({super.key, required this.spot, this.onTap});

  final ParkingSpot spot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final availability = spot.availability;
    final (Color background, Color foreground) = switch (availability) {
      SpotAvailability.available => (
        AppColors.spotAvailable,
        AppColors.onPrimary,
      ),
      SpotAvailability.reserved => (
        AppColors.spotReserved,
        AppColors.onPrimary,
      ),
      SpotAvailability.occupied => (
        AppColors.spotOccupied,
        AppColors.textPrimary,
      ),
      SpotAvailability.unavailable => (
        AppColors.spotUnavailable,
        AppColors.textPrimary,
      ),
    };
    final Color? borderColor =
        spot.hasUnvalidatedOccupancy ||
            availability == SpotAvailability.unavailable
        ? AppColors.danger
        : null;
    final label = spot.hasUnvalidatedOccupancy
        ? 'Unvalidated'
        : spot.guestSessionId != null &&
              availability == SpotAvailability.occupied
        ? 'Guest'
        : availability.label;

    return Semantics(
      button: true,
      label: 'Spot ${spot.code}, $label',
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor, width: 1.6),
        ),
        child: InkWell(
          key: Key('spot-${spot.code}'),
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spot.code,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  spot.type.code,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: spot.sensorReliable
                            ? AppColors.warning
                            : AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: foreground, fontSize: 10.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows occupancy, reservation and sensor as separate rows (US05).
class SpotStateTable extends StatelessWidget {
  const SpotStateTable({super.key, required this.spot, this.guestPlate});

  final ParkingSpot spot;
  final String? guestPlate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      children: [
        InfoRow(
          title: 'Occupancy (sensor)',
          subtitle: 'Physical state reported by the sensor',
          trailing: spot.occupancy.label,
        ),
        InfoRow(
          title: 'Reservation',
          subtitle: spot.reservationCode ?? 'No reservation linked',
          trailing: spot.reservation.label,
        ),
        InfoRow(
          title: 'Sensor',
          subtitle: spot.sensorId,
          trailing: spot.sensorHealth.label,
        ),
        InfoRow(
          title: 'Guest session',
          subtitle: guestPlate == null
              ? 'No guest session'
              : 'Plate $guestPlate',
          trailing: spot.guestSessionId ?? '-',
        ),
      ],
    );
  }
}

class SpotNotice extends StatelessWidget {
  const SpotNotice(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return NoticeCard(icon: Icons.info_outline, message: message);
  }
}
