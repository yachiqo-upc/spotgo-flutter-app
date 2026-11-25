import 'billing_types.dart';

/// `TokenView` (contract §3.1) — a stored, simulated payment method.
class PaymentToken {
  const PaymentToken({
    required this.tokenId,
    required this.profileId,
    required this.brand,
    required this.lastFour,
    required this.expirationMonth,
    required this.expirationYear,
    required this.status,
    required this.isDefault,
    required this.createdAt,
    this.revokedAt,
  });

  factory PaymentToken.fromJson(Map<String, dynamic> row) => PaymentToken(
    tokenId: row['tokenId'] as String,
    profileId: row['profileId'] as String? ?? '',
    brand: row['brand'] as String? ?? '',
    lastFour: row['lastFour'] as String? ?? '',
    expirationMonth: (row['expirationMonth'] as num?)?.toInt() ?? 0,
    expirationYear: (row['expirationYear'] as num?)?.toInt() ?? 0,
    status: PaymentTokenStatus.parse(row['status']),
    isDefault: row['isDefault'] == true,
    createdAt: DateTime.parse(row['createdAt'] as String),
    revokedAt: row['revokedAt'] is String
        ? DateTime.parse(row['revokedAt'] as String)
        : null,
  );

  final String tokenId;
  final String profileId;
  final String brand;
  final String lastFour;
  final int expirationMonth;
  final int expirationYear;
  final PaymentTokenStatus status;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime? revokedAt;

  String get maskedNumber => '$brand •••• $lastFour';

  String get expiration =>
      '${expirationMonth.toString().padLeft(2, '0')}/'
      '${expirationYear % 100}';

  bool get isActive => status == PaymentTokenStatus.active;
}
