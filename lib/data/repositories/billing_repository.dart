import '../models/additional_charge.dart';
import '../models/billing_document.dart';
import '../models/digital_payment.dart';
import '../models/payment_token.dart';
import '../models/refund.dart';
import '../models/subscription.dart';

/// Billing failure carrying the HTTP status so screens can branch on it
/// (404 "Create your profile first.", 409 conflicts, …).
class BillingException implements Exception {
  const BillingException(this.message, {this.status = 0});

  final String message;
  final int status;

  /// True when the account has no profile yet (contract H1).
  bool get isMissingProfile =>
      status == 404 && message.toLowerCase().contains('profile');

  @override
  String toString() => message;
}

/// Contract for the Billing bounded context (contract §1.5, 30 endpoints).
/// A REST implementation and an in-memory mock are interchangeable.
abstract interface class BillingRepository {
  // ── Payment tokens (TOK-01…04) ────────────────────────────────────────
  Future<List<PaymentToken>> listTokens();

  /// [providerTokenRef] must be `simulated-(visa|mastercard|amex|discover)-NNNN`.
  Future<PaymentToken> createToken(String providerTokenRef);

  Future<PaymentToken> setDefaultToken(String tokenId);

  /// Revokes the token; the backend answers 200 with the revoked `TokenView`.
  Future<PaymentToken> revokeToken(String tokenId);

  // ── Digital payments (PAY-01…09) ──────────────────────────────────────
  Future<List<DigitalPayment>> listPayments();

  Future<DigitalPayment> getPayment(String paymentId);

  /// PAY-05. Reservation (PAY-03), reservation change (PAY-04) and additional
  /// charge (PAY-06) payments are DRIVER-only and are deliberately absent.
  Future<DigitalPayment> createSubscriptionPayment({
    required String planCode,
    required String tokenId,
    required String idempotencyKey,
  });

  Future<DigitalPayment> processPayment(String paymentId);

  /// [tokenId] is optional; the whole body is optional (PAY-08).
  Future<DigitalPayment> retryPayment(String paymentId, {String? tokenId});

  Future<DigitalPayment> reconcilePayment(String paymentId);

  Future<List<PaymentAttempt>> listAttempts(String paymentId);

  // ── Subscriptions (SUB-01…05) ─────────────────────────────────────────
  /// Catalog restricted to `PARKING_ADMIN` plans: SUB-02 itself is
  /// unfiltered, so DRIVER plans are removed before they reach the UI.
  Future<List<SubscriptionPlan>> listPlans();

  /// 403 when [planCode] belongs to another audience (contract SUB-03).
  Future<SubscriptionPlan> quotePlan(String planCode);

  Future<List<Subscription>> listSubscriptions();

  Future<Subscription> cancelSubscription(String subscriptionId);

  // ── Additional charges (CHG-01…03) ────────────────────────────────────
  Future<List<AdditionalCharge>> listCharges();

  Future<AdditionalCharge> createCharge({
    required String reservationId,
    required int amountCents,
    required String reason,
    required String evidenceRef,
  });

  Future<OutstandingBalance> markChargeUnpaid(String chargeId);

  // ── Outstanding balances (BAL-01…02) ──────────────────────────────────
  Future<List<OutstandingBalance>> listBalances();

  /// Sum of the `OPEN` balances, in cents (`{"amount": n}`).
  Future<int> totalBalanceCents();

  // ── Refunds (REF-01…03, PA/SA) ───────────────────────────────────────
  /// Refunds of [paymentId] (REF-01). This app reaches [paymentId] through
  /// the tenant reservations (RES-01), never through a driver's payments.
  Future<List<Refund>> listRefunds(String paymentId);

  Future<Refund> requestRefund({
    required String paymentId,
    required int amountCents,
    required String reason,
  });

  Future<Refund> processRefund(String refundId);

  // ── Billing documents (DOC-01…03) ────────────────────────────────────
  /// `null` when the payment has no document yet (backend answers 404).
  Future<BillingDocument?> documentForPayment(String paymentId);

  Future<BillingDocument> issueDocument({
    required String paymentId,
    required String documentType,
    required String documentNumber,
    required String series,
    required String legalName,
    required String taxDataType,
    required String taxDataNumber,
  });

  Future<BillingDocument> voidDocument(String documentId);
}
