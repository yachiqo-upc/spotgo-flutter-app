import '../../core/api/role_guard.dart';
import '../models/additional_charge.dart';
import '../models/billing_document.dart';
import '../models/digital_payment.dart';
import '../models/payment_token.dart';
import '../models/refund.dart';
import '../models/subscription.dart';
import '../repositories/billing_repository.dart';
import 'spotgo_api.dart';

/// Real implementation of the Billing bounded context against `/api/v1`
/// (contract §1.5). Every call carries the Bearer token handled by [SpotGoApi].
class RemoteBillingRepository implements BillingRepository {
  RemoteBillingRepository(this.api);

  final SpotGoApi api;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on RoleGuardException catch (error) {
      // A DRIVER-only endpoint reached from this app is a contract 403.
      throw BillingException(error.message, status: 403);
    } on ApiException catch (error) {
      throw BillingException(error.message, status: error.status);
    }
  }

  /// Billing amounts travel as JSON numbers with two decimals.
  static double _amount(int cents) => cents / 100;

  // ── Payment tokens (TOK-01…04) ────────────────────────────────────────

  @override
  Future<List<PaymentToken>> listTokens() => _guard(() async =>
      (await api.list('/payment-tokens')).map(PaymentToken.fromJson).toList());

  @override
  Future<PaymentToken> createToken(String providerTokenRef) => _guard(() async =>
      PaymentToken.fromJson(await api.object(
        '/payment-tokens',
        method: 'POST',
        body: {'providerTokenRef': providerTokenRef},
      )));

  @override
  Future<PaymentToken> setDefaultToken(String tokenId) => _guard(() async =>
      PaymentToken.fromJson(
          await api.object('/payment-tokens/$tokenId/default', method: 'PUT')));

  /// The backend answers 200 with the revoked `TokenView`, not 204.
  @override
  Future<PaymentToken> revokeToken(String tokenId) => _guard(() async =>
      PaymentToken.fromJson(await api.object(
        '/payment-tokens/$tokenId',
        method: 'DELETE',
      )));

  // ── Digital payments (PAY-01…09) ──────────────────────────────────────

  @override
  Future<List<DigitalPayment>> listPayments() => _guard(() async =>
      (await api.list('/digital-payments'))
          .map(DigitalPayment.fromJson)
          .toList());

  @override
  Future<DigitalPayment> getPayment(String paymentId) => _guard(() async =>
      DigitalPayment.fromJson(
          await api.object('/digital-payments/$paymentId')));

  Future<DigitalPayment> _createPayment(String path, Json body) =>
      _guard(() async =>
          DigitalPayment.fromJson(await api.object(path, method: 'POST', body: body)));

  /// PAY-05 (D, PA). The quote doubles as the audience guard: SUB-03 answers
  /// 403 "plan de otra audiencia" before a DRIVER plan can be charged.
  @override
  Future<DigitalPayment> createSubscriptionPayment({
    required String planCode,
    required String tokenId,
    required String idempotencyKey,
  }) async {
    await quotePlan(planCode);
    return _createPayment(
      '/digital-payments/subscriptions',
      {
        'planCode': planCode,
        'tokenId': tokenId,
        'idempotencyKey': idempotencyKey,
      },
    );
  }

  @override
  Future<DigitalPayment> processPayment(String paymentId) => _guard(() async =>
      DigitalPayment.fromJson(await api.object(
          '/digital-payments/$paymentId/process',
          method: 'POST')));

  @override
  Future<DigitalPayment> retryPayment(String paymentId, {String? tokenId}) =>
      _guard(() async => DigitalPayment.fromJson(
            await api.object(
              '/digital-payments/$paymentId/retry',
              method: 'POST',
              body: tokenId == null ? null : {'tokenId': tokenId},
            ),
          ));

  @override
  Future<DigitalPayment> reconcilePayment(String paymentId) =>
      _guard(() async => DigitalPayment.fromJson(await api.object(
            '/digital-payments/$paymentId/reconcile',
            method: 'POST',
          )));

  @override
  Future<List<PaymentAttempt>> listAttempts(String paymentId) =>
      _guard(() async => (await api.list('/payment-attempts', {
            'paymentId': paymentId,
          }))
              .map(PaymentAttempt.fromJson)
              .toList());

  // ── Subscriptions (SUB-01…05) ─────────────────────────────────────────

  /// SUB-02 answers the whole catalog (D and PA plans included). DRIVER rows
  /// are dropped here so this app never offers a plan it cannot pay for.
  @override
  Future<List<SubscriptionPlan>> listPlans() => _guard(() async =>
      (await api.list('/subscriptions/plans'))
          .map(SubscriptionPlan.fromJson)
          .where((plan) => plan.isParkingAdminPlan)
          .toList());

  @override
  Future<SubscriptionPlan> quotePlan(String planCode) => _guard(() async {
        final plan = SubscriptionPlan.fromJson(
            await api.object('/subscriptions/plans/$planCode/quote'));
        // The backend already answers 403 for another audience; this check
        // keeps the app from charging a plan the quote did not authorize.
        if (plan.audience.isNotEmpty && !plan.isParkingAdminPlan) {
          throw BillingException(
            'The plan $planCode belongs to another audience; '
            '${RoleGuard.appRole} accounts cannot subscribe to it.',
            status: 403,
          );
        }
        return plan;
      });

  @override
  Future<List<Subscription>> listSubscriptions() => _guard(() async =>
      (await api.list('/subscriptions')).map(Subscription.fromJson).toList());

  @override
  Future<Subscription> cancelSubscription(String subscriptionId) =>
      _guard(() async => Subscription.fromJson(await api.object(
            '/subscriptions/$subscriptionId/cancel',
            method: 'POST',
          )));

  // ── Additional charges (CHG-01…03) ────────────────────────────────────

  @override
  Future<List<AdditionalCharge>> listCharges() => _guard(() async =>
      (await api.list('/additional-charges'))
          .map(AdditionalCharge.fromJson)
          .toList());

  @override
  Future<AdditionalCharge> createCharge({
    required String reservationId,
    required int amountCents,
    required String reason,
    required String evidenceRef,
  }) => _guard(() async => AdditionalCharge.fromJson(await api.object(
        '/additional-charges',
        method: 'POST',
        body: {
          'reservationId': reservationId,
          'amount': _amount(amountCents),
          'reason': reason,
          'evidenceRef': evidenceRef,
        },
      )));

  @override
  Future<OutstandingBalance> markChargeUnpaid(String chargeId) =>
      _guard(() async => OutstandingBalance.fromJson(await api.object(
            '/additional-charges/$chargeId/mark-unpaid',
            method: 'POST',
          )));

  // ── Outstanding balances (BAL-01…02) ──────────────────────────────────

  @override
  Future<List<OutstandingBalance>> listBalances() => _guard(() async =>
      (await api.list('/outstanding-balances'))
          .map(OutstandingBalance.fromJson)
          .toList());

  @override
  Future<int> totalBalanceCents() => _guard(() async {
        final row = await api.object('/outstanding-balances/total');
        return centsOf(row['amount']);
      });

  // ── Refunds (REF-01…03) ──────────────────────────────────────────────

  @override
  Future<List<Refund>> listRefunds(String paymentId) =>
      _guard(() async => (await api.list('/refunds', {'paymentId': paymentId}))
          .map(Refund.fromJson)
          .toList());

  @override
  Future<Refund> requestRefund({
    required String paymentId,
    required int amountCents,
    required String reason,
  }) => _guard(() async => Refund.fromJson(await api.object(
        '/refunds',
        method: 'POST',
        body: {
          'paymentId': paymentId,
          'amount': _amount(amountCents),
          'reason': reason,
        },
      )));

  @override
  Future<Refund> processRefund(String refundId) =>
      _guard(() async => Refund.fromJson(await api.object(
            '/refunds/$refundId/process',
            method: 'POST',
            body: {},
          )));

  // ── Billing documents (DOC-01…03) ────────────────────────────────────

  /// DOC-01 answers 404 "Billing document not found" when the payment has
  /// no document, which the caller reads as "none yet".
  @override
  Future<BillingDocument?> documentForPayment(String paymentId) async {
    try {
      return BillingDocument.fromJson(
        await api.object('/billing-documents', query: {'paymentId': paymentId}),
      );
    } on ApiException catch (error) {
      if (error.status == 404) return null;
      throw BillingException(error.message, status: error.status);
    }
  }

  @override
  Future<BillingDocument> issueDocument({
    required String paymentId,
    required String documentType,
    required String documentNumber,
    required String series,
    required String legalName,
    required String taxDataType,
    required String taxDataNumber,
  }) => _guard(() async => BillingDocument.fromJson(await api.object(
        '/billing-documents',
        method: 'POST',
        body: {
          'paymentId': paymentId,
          'documentType': documentType,
          'documentNumber': documentNumber,
          'series': series,
          'legalName': legalName,
          'taxData': {
            'document_type': taxDataType,
            'document_number': taxDataNumber,
          },
        },
      )));

  @override
  Future<BillingDocument> voidDocument(String documentId) =>
      _guard(() async => BillingDocument.fromJson(await api.object(
            '/billing-documents/$documentId/void',
            method: 'POST',
          )));
}
