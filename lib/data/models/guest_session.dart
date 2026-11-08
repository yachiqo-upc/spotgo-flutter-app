enum GuestSessionStatus {
  open('Active'),
  closed('Completed'),
  pendingReview('Pending review');

  const GuestSessionStatus(this.label);

  final String label;
}

enum VehicleType {
  car('Car'),
  motorcycle('Motorcycle'),
  van('Van'),
  pickup('Pickup');

  const VehicleType(this.label);

  final String label;
}

/// Payment collected outside SpotGo. No card or financial data is stored.
enum PhysicalPaymentMethod {
  cash('Cash'),
  externalPos('External POS');

  const PhysicalPaymentMethod(this.label);

  final String label;
}

/// Manual session for an external vehicle. It has no Driver account,
/// persistent vehicle, reservation or digital payment.
class GuestSession {
  const GuestSession({
    required this.id,
    required this.plate,
    required this.vehicleType,
    required this.zoneId,
    required this.spotId,
    required this.spotCode,
    required this.entryAt,
    required this.expectedDuration,
    required this.status,
    this.color,
    this.exitAt,
    this.amount,
    this.paymentMethod,
    this.paymentConfirmed = false,
    this.paymentReference,
  });

  final String id;
  final String plate;
  final VehicleType vehicleType;
  final String? color;
  final String zoneId;
  final String spotId;
  final String spotCode;
  final DateTime entryAt;
  final Duration expectedDuration;
  final DateTime? exitAt;
  final double? amount;
  final PhysicalPaymentMethod? paymentMethod;
  final bool paymentConfirmed;

  /// Optional receipt or POS voucher number written by the operator.
  final String? paymentReference;
  final GuestSessionStatus status;

  static const overstayTolerance = Duration(minutes: 5);

  DateTime get expectedCheckout => entryAt.add(expectedDuration);
  bool get isClosed => status == GuestSessionStatus.closed;
  bool get exitRegistered => exitAt != null;

  Duration elapsed(DateTime now) => (exitAt ?? now).difference(entryAt);

  bool isOverstay(DateTime now) =>
      !isClosed && (exitAt ?? now).isAfter(expectedCheckout.add(overstayTolerance));

  bool hasIssue(DateTime now) =>
      status == GuestSessionStatus.pendingReview || isOverstay(now);

  GuestSession copyWith({
    DateTime? exitAt,
    double? amount,
    PhysicalPaymentMethod? paymentMethod,
    bool? paymentConfirmed,
    String? paymentReference,
    GuestSessionStatus? status,
  }) {
    return GuestSession(
      id: id,
      plate: plate,
      vehicleType: vehicleType,
      color: color,
      zoneId: zoneId,
      spotId: spotId,
      spotCode: spotCode,
      entryAt: entryAt,
      expectedDuration: expectedDuration,
      exitAt: exitAt ?? this.exitAt,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentConfirmed: paymentConfirmed ?? this.paymentConfirmed,
      paymentReference: paymentReference ?? this.paymentReference,
      status: status ?? this.status,
    );
  }
}
