import 'parking_spot.dart';

enum ZoneStatus {
  active('Active'),
  unavailable('Unavailable');

  const ZoneStatus(this.label);

  final String label;
}

class ParkingZone {
  const ParkingZone({
    required this.id,
    required this.name,
    required this.address,
    required this.district,
    required this.opensAtMinutes,
    required this.closesAtMinutes,
    required this.ratePerHour,
    required this.billingFractionMinutes,
    required this.status,
    required this.allowedTypes,
    required this.spotIds,
  });

  final String id;
  final String name;
  final String address;
  final String district;

  /// Operating hours as minutes since midnight.
  final int opensAtMinutes;
  final int closesAtMinutes;
  final double ratePerHour;
  final int billingFractionMinutes;
  final ZoneStatus status;
  final Set<SpotType> allowedTypes;
  final List<String> spotIds;

  int get totalSpots => spotIds.length;
  bool get isActive => status == ZoneStatus.active;

  ParkingZone copyWith({
    String? name,
    String? address,
    String? district,
    int? opensAtMinutes,
    int? closesAtMinutes,
    double? ratePerHour,
    int? billingFractionMinutes,
    ZoneStatus? status,
    Set<SpotType>? allowedTypes,
    List<String>? spotIds,
  }) {
    return ParkingZone(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      district: district ?? this.district,
      opensAtMinutes: opensAtMinutes ?? this.opensAtMinutes,
      closesAtMinutes: closesAtMinutes ?? this.closesAtMinutes,
      ratePerHour: ratePerHour ?? this.ratePerHour,
      billingFractionMinutes:
          billingFractionMinutes ?? this.billingFractionMinutes,
      status: status ?? this.status,
      allowedTypes: allowedTypes ?? this.allowedTypes,
      spotIds: spotIds ?? this.spotIds,
    );
  }
}
