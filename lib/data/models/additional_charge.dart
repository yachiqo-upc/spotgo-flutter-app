import 'billing_types.dart';
import 'digital_payment.dart';

/// `ChargeView` (contract §3.1).
class AdditionalCharge {
  const AdditionalCharge({
    required this.chargeId,
    required this.reservationId,
    required this.amountCents,
    required this.reason,
    required this.evidenceRef,
    required this.status,
    required this.createdAt,
    this.paymentId,
  });

  factory AdditionalCharge.fromJson(Map<String, dynamic> row) =>
      AdditionalCharge(
        chargeId: row['chargeId'] as String,
        reservationId: row['reservationId'] as String? ?? '',
        paymentId: row['paymentId'] as String?,
        amountCents: centsOf(row['amount']),
        reason: row['reason'] as String? ?? '',
        evidenceRef: row['evidenceRef'] as String? ?? '',
        status: AdditionalChargeStatus.parse(row['status']),
        createdAt: DateTime.parse(row['createdAt'] as String),
      );

  final String chargeId;
  final String reservationId;
  final String? paymentId;
  final int amountCents;
  final String reason;
  final String evidenceRef;
  final AdditionalChargeStatus status;
  final DateTime createdAt;

  bool get canBePaid =>
      paymentId == null && status == AdditionalChargeStatus.pending;
}

/// `BalanceView` (contract §3.1) — an open debt created from a charge.
class OutstandingBalance {
  const OutstandingBalance({
    required this.balanceId,
    required this.profileId,
    required this.chargeId,
    required this.amountCents,
    required this.dueAt,
    required this.status,
    required this.createdAt,
    this.regularizedAt,
  });

  factory OutstandingBalance.fromJson(Map<String, dynamic> row) =>
      OutstandingBalance(
        balanceId: row['balanceId'] as String,
        profileId: row['profileId'] as String? ?? '',
        chargeId: row['chargeId'] as String? ?? '',
        amountCents: centsOf(row['amount']),
        dueAt: DateTime.parse(row['dueAt'] as String),
        status: OutstandingBalanceStatus.parse(row['status']),
        createdAt: DateTime.parse(row['createdAt'] as String),
        regularizedAt: row['regularizedAt'] is String
            ? DateTime.parse(row['regularizedAt'] as String)
            : null,
      );

  final String balanceId;
  final String profileId;
  final String chargeId;
  final int amountCents;
  final DateTime dueAt;
  final OutstandingBalanceStatus status;
  final DateTime createdAt;
  final DateTime? regularizedAt;
}
