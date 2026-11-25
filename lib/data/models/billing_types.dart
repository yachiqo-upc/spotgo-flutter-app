/// Billing enumerations taken from the API contract (§5.3).
///
/// Every parser keeps an `unknown` fallback because the backend can add
/// values without updating the app.
enum PaymentStatus {
  initiated,
  pending,
  approved,
  rejected,
  cancelled,
  reconciliationRequired,
  unknown;

  static PaymentStatus parse(Object? raw) => switch (raw) {
    'INITIATED' => PaymentStatus.initiated,
    'PENDING' => PaymentStatus.pending,
    'APPROVED' => PaymentStatus.approved,
    'REJECTED' => PaymentStatus.rejected,
    'CANCELLED' => PaymentStatus.cancelled,
    'RECONCILIATION_REQUIRED' => PaymentStatus.reconciliationRequired,
    _ => PaymentStatus.unknown,
  };

  String get label => switch (this) {
    PaymentStatus.initiated => 'Initiated',
    PaymentStatus.pending => 'Pending',
    PaymentStatus.approved => 'Approved',
    PaymentStatus.rejected => 'Rejected',
    PaymentStatus.cancelled => 'Cancelled',
    PaymentStatus.reconciliationRequired => 'In review',
    PaymentStatus.unknown => 'Unknown',
  };

  /// Statuses that will not change on their own any more.
  bool get isTerminal =>
      this == PaymentStatus.approved ||
      this == PaymentStatus.rejected ||
      this == PaymentStatus.cancelled;
}

enum PaymentOperationType {
  reservation,
  reservationAdjustment,
  subscription,
  subscriptionAdjustment,
  additionalCharge,
  refund,
  unknown;

  static PaymentOperationType parse(Object? raw) => switch (raw) {
    'RESERVATION' => PaymentOperationType.reservation,
    'RESERVATION_ADJUSTMENT' => PaymentOperationType.reservationAdjustment,
    'SUBSCRIPTION' => PaymentOperationType.subscription,
    'SUBSCRIPTION_ADJUSTMENT' => PaymentOperationType.subscriptionAdjustment,
    'ADDITIONAL_CHARGE' => PaymentOperationType.additionalCharge,
    'REFUND' => PaymentOperationType.refund,
    _ => PaymentOperationType.unknown,
  };

  String get label => switch (this) {
    PaymentOperationType.reservation => 'Reservation',
    PaymentOperationType.reservationAdjustment => 'Reservation change',
    PaymentOperationType.subscription => 'Subscription',
    PaymentOperationType.subscriptionAdjustment => 'Subscription change',
    PaymentOperationType.additionalCharge => 'Additional charge',
    PaymentOperationType.refund => 'Refund',
    PaymentOperationType.unknown => 'Other',
  };
}

enum PaymentTokenStatus {
  active,
  revoked,
  unknown;

  static PaymentTokenStatus parse(Object? raw) => switch (raw) {
    'ACTIVE' => PaymentTokenStatus.active,
    'REVOKED' => PaymentTokenStatus.revoked,
    _ => PaymentTokenStatus.unknown,
  };

  String get label => switch (this) {
    PaymentTokenStatus.active => 'Active',
    PaymentTokenStatus.revoked => 'Revoked',
    PaymentTokenStatus.unknown => 'Unknown',
  };
}

enum SubscriptionStatus {
  active,
  paused,
  expired,
  pastDue,
  cancelled,
  unknown;

  static SubscriptionStatus parse(Object? raw) => switch (raw) {
    'ACTIVE' => SubscriptionStatus.active,
    'PAUSED' => SubscriptionStatus.paused,
    'EXPIRED' => SubscriptionStatus.expired,
    'PAST_DUE' => SubscriptionStatus.pastDue,
    'CANCELLED' => SubscriptionStatus.cancelled,
    _ => SubscriptionStatus.unknown,
  };

  String get label => switch (this) {
    SubscriptionStatus.active => 'Active',
    SubscriptionStatus.paused => 'Paused',
    SubscriptionStatus.expired => 'Expired',
    SubscriptionStatus.pastDue => 'Past due',
    SubscriptionStatus.cancelled => 'Cancelled',
    SubscriptionStatus.unknown => 'Unknown',
  };
}

enum AdditionalChargeStatus {
  pending,
  paid,
  cancelled,
  unknown;

  static AdditionalChargeStatus parse(Object? raw) => switch (raw) {
    'PENDING' => AdditionalChargeStatus.pending,
    'PAID' => AdditionalChargeStatus.paid,
    'CANCELLED' => AdditionalChargeStatus.cancelled,
    _ => AdditionalChargeStatus.unknown,
  };

  String get label => switch (this) {
    AdditionalChargeStatus.pending => 'Pending',
    AdditionalChargeStatus.paid => 'Paid',
    AdditionalChargeStatus.cancelled => 'Cancelled',
    AdditionalChargeStatus.unknown => 'Unknown',
  };
}

enum OutstandingBalanceStatus {
  open,
  regularized,
  unknown;

  static OutstandingBalanceStatus parse(Object? raw) => switch (raw) {
    'OPEN' => OutstandingBalanceStatus.open,
    'REGULARIZED' => OutstandingBalanceStatus.regularized,
    _ => OutstandingBalanceStatus.unknown,
  };

  String get label => switch (this) {
    OutstandingBalanceStatus.open => 'Open',
    OutstandingBalanceStatus.regularized => 'Settled',
    OutstandingBalanceStatus.unknown => 'Unknown',
  };
}

enum RefundStatus {
  requested,
  processing,
  completed,
  failed,
  reconciliationRequired,
  unknown;

  static RefundStatus parse(Object? raw) => switch (raw) {
    'REQUESTED' => RefundStatus.requested,
    'PROCESSING' => RefundStatus.processing,
    'COMPLETED' => RefundStatus.completed,
    'FAILED' => RefundStatus.failed,
    'RECONCILIATION_REQUIRED' => RefundStatus.reconciliationRequired,
    _ => RefundStatus.unknown,
  };

  String get label => switch (this) {
    RefundStatus.requested => 'Requested',
    RefundStatus.processing => 'Processing',
    RefundStatus.completed => 'Completed',
    RefundStatus.failed => 'Failed',
    RefundStatus.reconciliationRequired => 'In review',
    RefundStatus.unknown => 'Unknown',
  };
}

enum BillingDocumentType {
  electronicReceipt,
  electronicInvoice,
  unknown;

  static BillingDocumentType parse(Object? raw) => switch (raw) {
    'ELECTRONIC_RECEIPT' => BillingDocumentType.electronicReceipt,
    'ELECTRONIC_INVOICE' => BillingDocumentType.electronicInvoice,
    _ => BillingDocumentType.unknown,
  };

  /// Wire value required by `DocumentBody.documentType`.
  String get wire => switch (this) {
    BillingDocumentType.electronicReceipt => 'ELECTRONIC_RECEIPT',
    BillingDocumentType.electronicInvoice => 'ELECTRONIC_INVOICE',
    BillingDocumentType.unknown => 'ELECTRONIC_RECEIPT',
  };

  String get label => switch (this) {
    BillingDocumentType.electronicReceipt => 'Electronic receipt',
    BillingDocumentType.electronicInvoice => 'Electronic invoice',
    BillingDocumentType.unknown => 'Document',
  };
}

enum BillingDocumentStatus {
  issued,
  voided,
  unknown;

  static BillingDocumentStatus parse(Object? raw) => switch (raw) {
    'ISSUED' => BillingDocumentStatus.issued,
    'VOID' => BillingDocumentStatus.voided,
    _ => BillingDocumentStatus.unknown,
  };

  String get label => switch (this) {
    BillingDocumentStatus.issued => 'Issued',
    BillingDocumentStatus.voided => 'Void',
    BillingDocumentStatus.unknown => 'Unknown',
  };
}
