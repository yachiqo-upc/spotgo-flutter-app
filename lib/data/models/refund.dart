import 'billing_types.dart';
import 'digital_payment.dart';

/// `RefundView` (contract §3.1).
class Refund {
  const Refund({
    required this.refundId,
    required this.paymentId,
    required this.amountCents,
    required this.reason,
    required this.status,
    required this.requestedAt,
    this.providerOperationRef,
    this.completedAt,
  });

  factory Refund.fromJson(Map<String, dynamic> row) => Refund(
    refundId: row['refundId'] as String,
    paymentId: row['paymentId'] as String? ?? '',
    amountCents: centsOf(row['amount']),
    reason: row['reason'] as String? ?? '',
    status: RefundStatus.parse(row['status']),
    providerOperationRef: row['providerOperationRef'] as String?,
    requestedAt: DateTime.parse(row['requestedAt'] as String),
    completedAt: row['completedAt'] is String
        ? DateTime.parse(row['completedAt'] as String)
        : null,
  );

  final String refundId;
  final String paymentId;
  final int amountCents;
  final String reason;
  final RefundStatus status;
  final String? providerOperationRef;
  final DateTime requestedAt;
  final DateTime? completedAt;
}
