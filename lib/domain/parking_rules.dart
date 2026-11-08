import '../data/models/parking_spot.dart';
import '../data/models/parking_zone.dart';

class ParkingRuleException implements Exception {
  const ParkingRuleException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Business rules from the SpotGo documentation (US02, US03, US05, US06).
abstract final class ParkingRules {
  static const double highOccupancyThreshold = 0.95;
  static const int minActionLength = 5;

  static final RegExp _plateChars = RegExp(r'^[A-Z0-9]{6,7}$');

  /// Uppercases and removes spaces/dashes, then formats as `ABC-123`.
  static String normalizePlate(String raw) {
    final compact = raw.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (compact.length == 6) {
      return '${compact.substring(0, 3)}-${compact.substring(3)}';
    }
    return compact;
  }

  static String? validatePlate(String? raw) {
    final compact = (raw ?? '').toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (compact.isEmpty) return 'Enter the license plate';
    if (!_plateChars.hasMatch(compact)) {
      return 'Use 6 or 7 letters/numbers, e.g. B7N-216';
    }
    return null;
  }

  /// Amount for a guest session charged by billing fractions. At least one
  /// fraction is charged once the session starts.
  static double guestAmount({
    required DateTime entryAt,
    required DateTime exitAt,
    required double ratePerHour,
    required int billingFractionMinutes,
  }) {
    if (billingFractionMinutes <= 0) {
      throw const ParkingRuleException('Billing fraction must be positive');
    }
    final minutes = exitAt.difference(entryAt).inSeconds / 60;
    final fractions = minutes <= 0
        ? 1
        : (minutes / billingFractionMinutes).ceil();
    final amount = fractions * billingFractionMinutes / 60 * ratePerHour;
    return (amount * 100).roundToDouble() / 100;
  }

  /// Spots with a reliable sensor reading (operational for monitoring).
  static List<ParkingSpot> operationalSpots(List<ParkingSpot> spots) => spots
      .where(
        (s) => s.sensorReliable && s.occupancy != OccupancyStatus.unavailable,
      )
      .toList();

  /// Physically occupied spots according to reliable sensor readings only;
  /// reservations and guest sessions do not count as presence (US05).
  static int physicallyOccupied(List<ParkingSpot> spots) =>
      operationalSpots(spots)
          .where((s) => s.occupancy == OccupancyStatus.occupied)
          .length;

  /// Occupancy ratio over operational spots (unavailable spots excluded).
  static double occupancyRatio(List<ParkingSpot> spots) {
    final operational = operationalSpots(spots);
    if (operational.isEmpty) return 0;
    return physicallyOccupied(spots) / operational.length;
  }

  static bool isHighOccupancy(List<ParkingSpot> spots) =>
      occupancyRatio(spots) > highOccupancyThreshold;

  /// Throws if the spot cannot receive a guest session (US03, scenario 2).
  static void ensureGuestSpotAvailable(ParkingSpot spot, ParkingZone zone) {
    if (!zone.isActive) {
      throw ParkingRuleException(
        '${zone.name} is unavailable. Select a spot in an active zone.',
      );
    }
    if (!spot.canStartGuestSession) {
      throw ParkingRuleException(
        'Spot ${spot.code} is ${spot.availability.label}. '
        'Select an Available spot.',
      );
    }
  }

  static String? validateOperatingHours(int? opensAt, int? closesAt) {
    if (opensAt == null || closesAt == null) {
      return 'Select opening and closing hours';
    }
    if (closesAt <= opensAt) return 'Closing time must be after opening time';
    return null;
  }

  /// Spots already assigned to another zone cannot be saved (US02, scenario 2).
  static List<String> conflictingSpots({
    required String? zoneId,
    required List<String> selectedSpotIds,
    required List<ParkingZone> zones,
  }) {
    final conflicts = <String>[];
    for (final zone in zones) {
      if (zone.id == zoneId) continue;
      conflicts.addAll(zone.spotIds.where(selectedSpotIds.contains));
    }
    return conflicts;
  }

  /// An alert is resolved only with classification and a completed action
  /// (US06, scenario 4). Returns an error message or null.
  static String? validateAlertResolution({
    required String? classification,
    required String? action,
    required bool actionCompleted,
  }) {
    if (classification == null || classification.isEmpty) {
      return 'Select the incident classification';
    }
    if ((action ?? '').trim().length < minActionLength) {
      return 'Describe the action taken';
    }
    if (!actionCompleted) {
      return 'The alert can be resolved only after the action is completed';
    }
    return null;
  }
}
