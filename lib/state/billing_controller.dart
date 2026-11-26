import 'package:flutter/foundation.dart';

import '../core/utils/idempotency.dart';
import '../data/models/additional_charge.dart';
import '../data/models/billing_document.dart';
import '../data/models/billing_types.dart';
import '../data/models/digital_payment.dart';
import '../data/models/payment_token.dart';
import '../data/models/refund.dart';
import '../data/models/subscription.dart';
import '../data/repositories/billing_repository.dart';

/// Holds the billing state of the signed in account and runs the Billing
/// use cases through [BillingRepository]. Screens listen through `AppScope`.
class BillingController extends ChangeNotifier {
  BillingController({required this._repository, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final BillingRepository _repository;
  final DateTime Function() _clock;

  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<PaymentToken> _tokens = const [];
  List<DigitalPayment> _payments = const [];
  List<SubscriptionPlan> _plans = const [];
  List<Subscription> _subscriptions = const [];
  List<AdditionalCharge> _charges = const [];
  List<OutstandingBalance> _balances = const [];
  int _balanceCents = 0;

  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  /// Set when the backend answers 404 "Create your profile first." (H1).
  bool needsProfile = false;

  List<PaymentToken> get tokens => _tokens;
  List<PaymentToken> get activeTokens =>
      _tokens.where((t) => t.isActive).toList();
  List<DigitalPayment> get payments => _payments;
  List<SubscriptionPlan> get plans => _plans;
  List<Subscription> get subscriptions => _subscriptions;
  List<AdditionalCharge> get charges => _charges;
  bool hasBalanceForCharge(String chargeId) =>
      _balances.any((balance) => balance.chargeId == chargeId);
  int get balanceCents => _balanceCents;

  PaymentToken? get defaultToken =>
      _tokens.where((t) => t.isDefault && t.isActive).firstOrNull ??
      activeTokens.firstOrNull;

  Subscription? get activeSubscription => _subscriptions
      .where((s) => s.status == SubscriptionStatus.active)
      .firstOrNull;

  DigitalPayment? paymentById(String paymentId) =>
      _payments.where((p) => p.paymentId == paymentId).firstOrNull;

  bool get hasOpenBalances => _balanceCents > 0;

  // ── Loading ───────────────────────────────────────────────────────────

  /// Loads the billing data. Failures are kept in [error] instead of being
  /// rethrown so screens can fire it from `initState`.
  Future<void> load() => _quiet(
    _run(() async {
      _loading = true;
      _error = null;
      notifyListeners();
      try {
        final results = await Future.wait<Object?>([
          _repository.listTokens(),
          _repository.listPayments(),
          _repository.listPlans(),
          _repository.listSubscriptions(),
          _repository.listCharges(),
          _repository.listBalances(),
          _repository.totalBalanceCents(),
        ]);
        _tokens = results[0] as List<PaymentToken>;
        _payments = results[1] as List<DigitalPayment>;
        _plans = results[2] as List<SubscriptionPlan>;
        _subscriptions = results[3] as List<Subscription>;
        _charges = results[4] as List<AdditionalCharge>;
        _balances = results[5] as List<OutstandingBalance>;
        _balanceCents = results[6] as int;
        _loaded = true;
      } finally {
        _loading = false;
        notifyListeners();
      }
    }),
  );

  /// Reloads without hiding the current data.
  Future<void> refresh() => _quiet(
    _run(() async {
      final results = await Future.wait<Object?>([
        _repository.listTokens(),
        _repository.listPayments(),
        _repository.listSubscriptions(),
        _repository.listCharges(),
        _repository.listBalances(),
        _repository.totalBalanceCents(),
      ]);
      _tokens = results[0] as List<PaymentToken>;
      _payments = results[1] as List<DigitalPayment>;
      _subscriptions = results[2] as List<Subscription>;
      _charges = results[3] as List<AdditionalCharge>;
      _balances = results[4] as List<OutstandingBalance>;
      _balanceCents = results[5] as int;
      notifyListeners();
    }),
  );

  /// Awaits [action] and swallows its [BillingException]: `_run` already
  /// stored the message in [error].
  Future<void> _quiet<T>(Future<T> action) async {
    try {
      await action;
    } on BillingException {
      // Already surfaced through [error].
    }
  }

  /// Runs an action, surfacing its message through [error].
  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on BillingException catch (exception) {
      if (exception.isMissingProfile) needsProfile = true;
      _error = exception.message;
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Payment tokens (TOK-01…04) ────────────────────────────────────────

  Future<PaymentToken> addToken(String providerTokenRef) => _run(() async {
    final token = await _repository.createToken(providerTokenRef);
    _tokens = [..._tokens, token];
    notifyListeners();
    return token;
  });

  Future<PaymentToken> makeDefault(String tokenId) => _run(() async {
    final token = await _repository.setDefaultToken(tokenId);
    _tokens = [
      for (final item in _tokens)
        item.tokenId == tokenId
            ? token
            : PaymentToken(
                tokenId: item.tokenId,
                profileId: item.profileId,
                brand: item.brand,
                lastFour: item.lastFour,
                expirationMonth: item.expirationMonth,
                expirationYear: item.expirationYear,
                status: item.status,
                isDefault: false,
                createdAt: item.createdAt,
                revokedAt: item.revokedAt,
              ),
    ];
    notifyListeners();
    return token;
  });

  Future<PaymentToken> revoke(String tokenId) => _run(() async {
    final token = await _repository.revokeToken(tokenId);
    _tokens = [
      for (final item in _tokens) item.tokenId == tokenId ? token : item,
    ];
    notifyListeners();
    return token;
  });

  // ── Payments (PAY-01…09) ──────────────────────────────────────────────

  Future<DigitalPayment> createSubscriptionPayment({
    required String planCode,
    required String tokenId,
    required String idempotencyKey,
  }) => _track(
    _repository.createSubscriptionPayment(
      planCode: planCode,
      tokenId: tokenId,
      idempotencyKey: idempotencyKey,
    ),
  );

  Future<DigitalPayment> process(String paymentId) =>
      _track(_repository.processPayment(paymentId));

  Future<DigitalPayment> retry(String paymentId, {String? tokenId}) =>
      _track(_repository.retryPayment(paymentId, tokenId: tokenId));

  Future<DigitalPayment> reconcile(String paymentId) =>
      _track(_repository.reconcilePayment(paymentId));

  Future<DigitalPayment> payment(String paymentId) =>
      _track(_repository.getPayment(paymentId));

  Future<List<PaymentAttempt>> attempts(String paymentId) =>
      _run(() => _repository.listAttempts(paymentId));

  /// Keeps [payments] in sync with a fresh server answer.
  Future<DigitalPayment> _track(Future<DigitalPayment> action) =>
      _run(() async {
        final payment = await action;
        final known = _payments.indexWhere(
          (p) => p.paymentId == payment.paymentId,
        );
        _payments = known < 0
            ? [payment, ..._payments]
            : [
                for (final p in _payments)
                  p.paymentId == payment.paymentId ? payment : p,
              ];
        notifyListeners();
        return payment;
      });

  /// Polls `GET /digital-payments/{id}` until the payment reaches a terminal
  /// status, [timeout] elapses, or [shouldStop] asks to stop.
  Future<DigitalPayment> waitForPayment(
    String paymentId, {
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(seconds: 45),
    bool Function()? shouldStop,
    void Function(DigitalPayment payment)? onTick,
  }) async {
    final deadline = _clock().add(timeout);
    var latest = await payment(paymentId);
    onTick?.call(latest);
    while (!latest.status.isTerminal &&
        _clock().isBefore(deadline) &&
        !(shouldStop?.call() ?? false)) {
      await Future<void>.delayed(interval);
      latest = await payment(paymentId);
      onTick?.call(latest);
    }
    return latest;
  }

  String newIdempotencyKey({String prefix = 'payment'}) =>
      Idempotency.newKey(prefix: prefix);

  // ── Subscriptions (SUB-01…05) ─────────────────────────────────────────

  Future<SubscriptionPlan> quote(String planCode) =>
      _run(() => _repository.quotePlan(planCode));

  Future<Subscription> cancel(String subscriptionId) => _run(() async {
    final subscription = await _repository.cancelSubscription(subscriptionId);
    _subscriptions = [
      for (final item in _subscriptions)
        item.subscriptionId == subscriptionId ? subscription : item,
    ];
    notifyListeners();
    return subscription;
  });

  // ── Charges and balances (CHG-*, BAL-*) ──────────────────────────────

  Future<AdditionalCharge> createCharge({
    required String reservationId,
    required int amountCents,
    required String reason,
    required String evidenceRef,
  }) => _run(() async {
    final charge = await _repository.createCharge(
      reservationId: reservationId,
      amountCents: amountCents,
      reason: reason,
      evidenceRef: evidenceRef,
    );
    _charges = [charge, ..._charges];
    notifyListeners();
    return charge;
  });

  Future<OutstandingBalance> markUnpaid(String chargeId) => _run(() async {
    final balance = await _repository.markChargeUnpaid(chargeId);
    final results = await Future.wait<Object?>([
      _repository.listBalances(),
      _repository.totalBalanceCents(),
    ]);
    _balances = results[0] as List<OutstandingBalance>;
    _balanceCents = results[1] as int;
    notifyListeners();
    return balance;
  });

  Future<int> refreshBalance() => _run(() async {
    _balanceCents = await _repository.totalBalanceCents();
    notifyListeners();
    return _balanceCents;
  });

  // ── Refunds (REF-01…03) ──────────────────────────────────────────────

  Future<List<Refund>> refundsFor(String paymentId) =>
      _run(() => _repository.listRefunds(paymentId));

  Future<Refund> requestRefund({
    required String paymentId,
    required int amountCents,
    required String reason,
  }) => _run(
    () => _repository.requestRefund(
      paymentId: paymentId,
      amountCents: amountCents,
      reason: reason,
    ),
  );

  Future<Refund> processRefund(String refundId) =>
      _run(() => _repository.processRefund(refundId));

  // ── Billing documents (DOC-01…03) ────────────────────────────────────

  Future<BillingDocument?> documentFor(String paymentId) =>
      _run(() => _repository.documentForPayment(paymentId));

  Future<BillingDocument> issueDocument({
    required String paymentId,
    required String documentType,
    required String documentNumber,
    required String series,
    required String legalName,
    required String taxDataType,
    required String taxDataNumber,
  }) => _run(
    () => _repository.issueDocument(
      paymentId: paymentId,
      documentType: documentType,
      documentNumber: documentNumber,
      series: series,
      legalName: legalName,
      taxDataType: taxDataType,
      taxDataNumber: taxDataNumber,
    ),
  );

  Future<BillingDocument> voidDocument(String documentId) =>
      _run(() => _repository.voidDocument(documentId));
}
