import 'billing_types.dart';

/// `PaymentView` (contract §3.1). Money is held in integer cents so amounts
/// are never summed with `double`; the currency is always `PEN`.
class DigitalPayment {
  const DigitalPayment({
    required this.paymentId,
    required this.profileId,
    required this.operationType,
    required this.amountCents,
    required this.currency,
    required this.status,
    required this.idempotencyKey,
    required this.requestHash,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.createdAt,
    this.tokenId,
    this.providerOperationRef,
    this.resultReference,
    this.approvedAt,
  });

  factory DigitalPayment.fromJson(Map<String, dynamic> row) => DigitalPayment(
    paymentId: row['paymentId'] as String,
    tokenId: row['tokenId'] as String?,
    profileId: row['profileId'] as String? ?? '',
    operationType: PaymentOperationType.parse(row['operationType']),
    amountCents: centsOf(row['amount']),
    currency: row['currency'] as String? ?? 'PEN',
    status: PaymentStatus.parse(row['status']),
    providerOperationRef: row['providerOperationRef'] as String?,
    idempotencyKey: row['idempotencyKey'] as String? ?? '',
    requestHash: row['requestHash'] as String? ?? '',
    firstSeenAt: _date(row['firstSeenAt']),
    lastSeenAt: _date(row['lastSeenAt']),
    resultReference: row['resultReference'] as String?,
    createdAt: _date(row['createdAt']),
    approvedAt: row['approvedAt'] is String
        ? DateTime.parse(row['approvedAt'] as String)
        : null,
  );

  final String paymentId;
  final String? tokenId;
  final String profileId;
  final PaymentOperationType operationType;

  /// Amount in cents (PEN has 2 decimals).
  final int amountCents;
  final String currency;
  final PaymentStatus status;
  final String? providerOperationRef;
  final String idempotencyKey;
  final String requestHash;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final String? resultReference;
  final DateTime createdAt;
  final DateTime? approvedAt;
}

/// `AttemptView` (contract §3.1).
class PaymentAttempt {
  const PaymentAttempt({
    required this.attemptId,
    required this.paymentId,
    required this.attemptNumber,
    required this.startedAt,
    required this.status,
    this.finishedAt,
    this.errorCode,
    this.nextAttemptAt,
  });

  factory PaymentAttempt.fromJson(Map<String, dynamic> row) => PaymentAttempt(
    attemptId: row['attemptId'] as String,
    paymentId: row['paymentId'] as String,
    attemptNumber: (row['attemptNumber'] as num?)?.toInt() ?? 0,
    startedAt: _date(row['startedAt']),
    finishedAt: row['finishedAt'] is String
        ? DateTime.parse(row['finishedAt'] as String)
        : null,
    status: row['status'] as String? ?? '',
    errorCode: row['errorCode'] as String?,
    nextAttemptAt: row['nextAttemptAt'] is String
        ? DateTime.parse(row['nextAttemptAt'] as String)
        : null,
  );

  final String attemptId;
  final String paymentId;
  final int attemptNumber;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String status;
  final String? errorCode;
  final DateTime? nextAttemptAt;
}

/// Converts a JSON amount (`10.00`) into integer cents (`1000`).
int centsOf(Object? amount) =>
    amount is num ? (amount * 100).round() : 0;

DateTime _date(Object? value) =>
    value is String ? DateTime.parse(value) : DateTime.fromMillisecondsSinceEpoch(0);
