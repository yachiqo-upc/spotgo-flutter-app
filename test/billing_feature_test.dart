import 'package:flutter_test/flutter_test.dart';

import 'package:spotgo_mobile_app/data/mock/mock_billing_repository.dart';
import 'package:spotgo_mobile_app/data/models/billing_types.dart';
import 'package:spotgo_mobile_app/features/billing/billing_widgets.dart';

void main() {
  group('parseCents', () {
    test('converts only positive values with at most two decimals', () {
      expect(parseCents('12'), 1200);
      expect(parseCents('12.3'), 1230);
      expect(parseCents('12,34'), 1234);
      expect(parseCents('0.01'), 1);
      expect(parseCents('0.001'), isNull);
      expect(parseCents('1.234'), isNull);
      expect(parseCents('0.00'), isNull);
      expect(parseCents('-1'), isNull);
    });
  });

  test(
    'an approved subscription payment activates its plan in the mock',
    () async {
      final repository = MockBillingRepository(
        latency: Duration.zero,
        paymentResolutionDelay: Duration.zero,
      );
      const tokenId = 'token-0000-4000-8000-000000000071';

      final payment = await repository.createSubscriptionPayment(
        planCode: 'DRIVER_MONTHLY',
        tokenId: tokenId,
        idempotencyKey: 'test-subscription',
      );
      expect((await repository.quotePlan('TENANT_MONTHLY')).priceCents, 4200);
      await repository.processPayment(payment.paymentId);
      final approved = await repository.getPayment(payment.paymentId);
      final subscriptions = await repository.listSubscriptions();

      expect(approved.status, PaymentStatus.approved);
      expect(
        subscriptions
            .singleWhere(
              (subscription) =>
                  subscription.status == SubscriptionStatus.active,
            )
            .plan
            .code,
        'DRIVER_MONTHLY',
      );
    },
  );

  test('recording a charge balance twice does not duplicate it', () async {
    final repository = MockBillingRepository(latency: Duration.zero);
    final charge = await repository.createCharge(
      reservationId: 'reservation-test',
      amountCents: 125,
      reason: 'DAMAGE',
      evidenceRef: 'evidence-test',
    );

    final first = await repository.markChargeUnpaid(charge.chargeId);
    final second = await repository.markChargeUnpaid(charge.chargeId);
    final balances = await repository.listBalances();

    expect(second.balanceId, first.balanceId);
    expect(
      balances.where((balance) => balance.chargeId == charge.chargeId),
      hasLength(1),
    );
  });
}
