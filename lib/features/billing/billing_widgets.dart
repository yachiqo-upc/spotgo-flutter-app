import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/billing_types.dart';

/// Badge tone for every billing status (contract §5.3).
extension PaymentStatusTone on PaymentStatus {
  BadgeTone get tone => switch (this) {
    PaymentStatus.approved => BadgeTone.success,
    PaymentStatus.rejected => BadgeTone.danger,
    PaymentStatus.pending || PaymentStatus.initiated => BadgeTone.warning,
    PaymentStatus.reconciliationRequired => BadgeTone.info,
    PaymentStatus.cancelled || PaymentStatus.unknown => BadgeTone.neutral,
  };
}

extension TokenStatusTone on PaymentTokenStatus {
  BadgeTone get tone => switch (this) {
    PaymentTokenStatus.active => BadgeTone.success,
    PaymentTokenStatus.revoked ||
    PaymentTokenStatus.unknown => BadgeTone.neutral,
  };
}

extension SubscriptionStatusTone on SubscriptionStatus {
  BadgeTone get tone => switch (this) {
    SubscriptionStatus.active => BadgeTone.success,
    SubscriptionStatus.pastDue => BadgeTone.danger,
    SubscriptionStatus.paused => BadgeTone.warning,
    SubscriptionStatus.expired ||
    SubscriptionStatus.cancelled ||
    SubscriptionStatus.unknown => BadgeTone.neutral,
  };
}

extension ChargeStatusTone on AdditionalChargeStatus {
  BadgeTone get tone => switch (this) {
    AdditionalChargeStatus.paid => BadgeTone.success,
    AdditionalChargeStatus.pending => BadgeTone.warning,
    AdditionalChargeStatus.cancelled ||
    AdditionalChargeStatus.unknown => BadgeTone.neutral,
  };
}

extension BalanceStatusTone on OutstandingBalanceStatus {
  BadgeTone get tone => switch (this) {
    OutstandingBalanceStatus.regularized => BadgeTone.success,
    OutstandingBalanceStatus.open => BadgeTone.danger,
    OutstandingBalanceStatus.unknown => BadgeTone.neutral,
  };
}

extension RefundStatusTone on RefundStatus {
  BadgeTone get tone => switch (this) {
    RefundStatus.completed => BadgeTone.success,
    RefundStatus.failed => BadgeTone.danger,
    RefundStatus.requested || RefundStatus.processing => BadgeTone.warning,
    RefundStatus.reconciliationRequired => BadgeTone.info,
    RefundStatus.unknown => BadgeTone.neutral,
  };
}

extension DocumentStatusTone on BillingDocumentStatus {
  BadgeTone get tone => switch (this) {
    BillingDocumentStatus.issued => BadgeTone.success,
    BillingDocumentStatus.voided ||
    BillingDocumentStatus.unknown => BadgeTone.neutral,
  };
}

/// Standard page frame for the screens pushed on the "More" stack.
class BillingPage extends StatelessWidget {
  const BillingPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: PageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: title,
              subtitle: subtitle,
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).maybePop()
                  : null,
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Red banner used while a billing action fails; dismissible.
class BillingErrorBanner extends StatelessWidget {
  const BillingErrorBanner({super.key, required this.message, this.onDismiss});

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.dangerMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger, fontSize: 13.5),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
            ),
        ],
      ),
    );
  }
}

/// Money helper that keeps amounts in integer cents.
String money(int cents) => Formatters.moneyCents(cents);

/// Parses a positive amount (`12.50`) into cents, rejecting fractions smaller
/// than one cent and values with more than two decimal places.
int? parseCents(String raw) {
  final normalized = raw.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(normalized)) return null;

  final parts = normalized.split('.');
  final whole = int.tryParse(parts.first);
  if (whole == null) return null;
  final fraction = parts.length == 1
      ? 0
      : int.parse(parts.last.padRight(2, '0'));
  final cents = whole * 100 + fraction;
  return cents > 0 ? cents : null;
}
