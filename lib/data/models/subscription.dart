import 'billing_types.dart';
import 'digital_payment.dart';

/// One row of `GET /subscriptions/plans` (SUB-02).
///
/// Plan objects use **snake_case** (`billing_period_months`, `discount_percent`,
/// `app_usage_price`, `price_per_iot_device`) while every other DTO is
/// camelCase, so each field is mapped explicitly.
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.code,
    required this.audience,
    required this.billingPeriodMonths,
    this.priceCents,
    this.discountPercent,
    this.appUsagePriceCents,
    this.pricePerIotDeviceCents,
    this.includedSensors,
    this.licensedSpotIds = const [],
    this.parkingSpotCount,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> row) =>
      SubscriptionPlan(
        code: row['code'] as String? ?? '',
        audience: row['audience'] as String? ?? '',
        billingPeriodMonths:
            (row['billing_period_months'] as num?)?.toInt() ?? 0,
        priceCents: row['price'] == null ? null : centsOf(row['price']),
        discountPercent: (row['discount_percent'] as num?)?.toInt(),
        appUsagePriceCents: row['app_usage_price'] == null
            ? null
            : centsOf(row['app_usage_price']),
        pricePerIotDeviceCents: row['price_per_iot_device'] == null
            ? null
            : centsOf(row['price_per_iot_device']),
        includedSensors: (row['included_sensors'] as num?)?.toInt(),
        licensedSpotIds: [
          for (final id in row['licensed_spot_ids'] as List<dynamic>? ?? const [])
            if (id is String) id,
        ],
        parkingSpotCount: (row['parking_spot_count'] as num?)?.toInt(),
      );

  final String code;
  final String audience;
  final int billingPeriodMonths;

  /// `null` for the tenant plan in SUB-02: only the SUB-03 quote computes it.
  final int? priceCents;
  final int? discountPercent;
  final int? appUsagePriceCents;
  final int? pricePerIotDeviceCents;
  final int? includedSensors;
  final List<String> licensedSpotIds;
  final int? parkingSpotCount;

  bool get isDriverPlan => audience == 'DRIVER';
}

/// `SubscriptionView` (contract §3.1).
class Subscription {
  const Subscription({
    required this.subscriptionId,
    required this.paymentId,
    required this.plan,
    required this.startAt,
    required this.status,
    this.profileId,
    this.tenantId,
    this.endAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> row) => Subscription(
    subscriptionId: row['subscriptionId'] as String,
    profileId: row['profileId'] as String?,
    tenantId: row['tenantId'] as String?,
    paymentId: row['paymentId'] as String? ?? '',
    plan: SubscriptionPlan.fromJson(
      row['plan'] is Map<String, dynamic>
          ? row['plan'] as Map<String, dynamic>
          : const <String, dynamic>{},
    ),
    startAt: DateTime.parse(row['startAt'] as String),
    endAt: row['endAt'] is String
        ? DateTime.parse(row['endAt'] as String)
        : null,
    status: SubscriptionStatus.parse(row['status']),
  );

  final String subscriptionId;
  final String? profileId;
  final String? tenantId;
  final String paymentId;
  final SubscriptionPlan plan;
  final DateTime startAt;
  final DateTime? endAt;
  final SubscriptionStatus status;
}
