import '../../core/api/role_guard.dart';
import '../models/additional_charge.dart';
import '../models/billing_document.dart';
import '../models/billing_types.dart';
import '../models/digital_payment.dart';
import '../models/payment_token.dart';
import '../models/refund.dart';
import '../models/subscription.dart';
import '../repositories/billing_repository.dart';

/// In-memory Billing implementation used while the SpotGo backend is not
/// connected. It reproduces the simulator rules of the contract so the UI
/// behaves the same way against either repository:
///
/// * a token ending in `0000` → `REJECTED`,
/// * a token ending in `1111` → stays `PENDING` until it is reconciled,
/// * any other token → `APPROVED` after [paymentResolutionDelay],
/// * retrying a rejected payment inside 60 s → 409 "The retry is not
///   available yet.",
/// * [missingProfile] → 404 "Create your profile first.".
class MockBillingRepository implements BillingRepository {
  MockBillingRepository({
    DateTime Function()? clock,
    this.latency = const Duration(milliseconds: 300),
    this.paymentResolutionDelay = const Duration(seconds: 2),
    this.missingProfile = false,
  }) : _clock = clock ?? DateTime.now {
    _seed();
  }

  final DateTime Function() _clock;
  final Duration latency;
  final Duration paymentResolutionDelay;

  /// Emulates an account without a profile (contract H1).
  bool missingProfile;

  late final List<PaymentToken> _tokens;
  late final List<DigitalPayment> _payments;
  late final List<SubscriptionPlan> _plans;
  late final List<Subscription> _subscriptions;
  late final List<AdditionalCharge> _charges;
  late final List<OutstandingBalance> _balances;
  late final List<Refund> _refunds;
  late final List<BillingDocument> _documents;
  late final List<PaymentAttempt> _attempts;

  final List<String> _processed = [];
  final Map<String, String> _idempotency = {};
  final Map<String, DateTime> _retryBlockedUntil = {};
  final Map<String, DateTime> _pendingSince = {};
  int _sequence = 9000;

  String get _profileId => 'profile-0000-4000-8000-000000000012';

  Future<void> _delay() => Future<void>.delayed(latency);

  void _checkProfile() {
    if (missingProfile) {
      throw const BillingException('Create your profile first.', status: 404);
    }
  }

  BillingException _conflict(String message) =>
      BillingException(message, status: 409);

  String _nextId(String prefix) =>
      '$prefix-${(_sequence++).toRadixString(16).padLeft(12, '0')}';

  void _seed() {
    final now = _clock();
    _tokens = [
      PaymentToken(
        tokenId: 'token-0000-4000-8000-000000000071',
        profileId: _profileId,
        brand: 'VISA',
        lastFour: '4242',
        expirationMonth: 12,
        expirationYear: 2030,
        status: PaymentTokenStatus.active,
        isDefault: true,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
    ];
    _plans = const [
      SubscriptionPlan(
        code: 'DRIVER_MONTHLY',
        audience: 'DRIVER',
        billingPeriodMonths: 1,
        priceCents: 1500,
        discountPercent: 10,
      ),
      SubscriptionPlan(
        code: 'DRIVER_ANNUAL',
        audience: 'DRIVER',
        billingPeriodMonths: 12,
        priceCents: 16000,
        discountPercent: 15,
      ),
      SubscriptionPlan(
        code: 'TENANT_MONTHLY',
        audience: 'PARKING_ADMIN',
        billingPeriodMonths: 1,
        priceCents: 4200,
        appUsagePriceCents: 3000,
        pricePerIotDeviceCents: 100,
        includedSensors: 12,
      ),
    ];
    _subscriptions = [
      Subscription(
        subscriptionId: 'subscription-0000-4000-8000-000000000192',
        paymentId: 'payment-0000-4000-8000-000000000085',
        plan: _plans.last,
        startAt: now.subtract(const Duration(days: 12)),
        endAt: now.add(const Duration(days: 18)),
        status: SubscriptionStatus.active,
        tenantId: 'tenant-0000-4000-8000-000000000021',
      ),
    ];
    _payments = [
      DigitalPayment(
        paymentId: 'payment-0000-4000-8000-000000000085',
        tokenId: _tokens.first.tokenId,
        profileId: _profileId,
        operationType: PaymentOperationType.subscription,
        amountCents: 4200,
        currency: 'PEN',
        status: PaymentStatus.approved,
        providerOperationRef: 'demo-subscription-tenant',
        idempotencyKey: 'demo-subscription-tenant',
        requestHash: '11111111111111111111111111111111',
        firstSeenAt: now.subtract(const Duration(days: 12)),
        lastSeenAt: now.subtract(const Duration(days: 12)),
        createdAt: now.subtract(const Duration(days: 12)),
        approvedAt: now.subtract(const Duration(days: 12)),
      ),
      DigitalPayment(
        paymentId: 'payment-0000-4000-8000-000000000083',
        tokenId: _tokens.first.tokenId,
        profileId: _profileId,
        operationType: PaymentOperationType.additionalCharge,
        amountCents: 200,
        currency: 'PEN',
        status: PaymentStatus.approved,
        providerOperationRef: 'demo-charge-001',
        idempotencyKey: 'demo-charge-001',
        requestHash: '22222222222222222222222222222222',
        firstSeenAt: now.subtract(const Duration(days: 10)),
        lastSeenAt: now.subtract(const Duration(days: 10)),
        createdAt: now.subtract(const Duration(days: 10)),
        approvedAt: now.subtract(const Duration(days: 10)),
      ),
      // A driver's reservation payment (PAY-03). PAY-01 never returns it to
      // this account, but PAY-02 still resolves it by id, which is how the
      // refund flow reads the payment behind a tenant reservation (RES-01).
      DigitalPayment(
        paymentId: 'payment-0000-4000-8000-000000000081',
        tokenId: _tokens.first.tokenId,
        profileId: 'profile-0000-4000-8000-000000000042',
        operationType: PaymentOperationType.reservation,
        amountCents: 1000,
        currency: 'PEN',
        status: PaymentStatus.approved,
        providerOperationRef: 'reservation-0000-4000-8000-000000000091',
        idempotencyKey: 'demo-reservation-091',
        requestHash: '33333333333333333333333333333333',
        firstSeenAt: now.subtract(const Duration(days: 6)),
        lastSeenAt: now.subtract(const Duration(days: 6)),
        createdAt: now.subtract(const Duration(days: 6)),
        approvedAt: now.subtract(const Duration(days: 6)),
      ),
    ];
    _charges = [
      AdditionalCharge(
        chargeId: 'charge-0000-4000-8000-000000000202',
        reservationId: 'reservation-0000-4000-8000-000000000092',
        amountCents: 300,
        reason: 'DAMAGE',
        evidenceRef: 'demo://evidence/damage-002',
        status: AdditionalChargeStatus.pending,
        createdAt: now.subtract(const Duration(days: 9)),
      ),
      AdditionalCharge(
        chargeId: 'charge-0000-4000-8000-000000000203',
        reservationId: 'reservation-0000-4000-8000-000000000091',
        paymentId: 'payment-0000-4000-8000-000000000083',
        amountCents: 200,
        reason: 'DAMAGE',
        evidenceRef: 'demo://evidence/damage-001',
        status: AdditionalChargeStatus.paid,
        createdAt: now.subtract(const Duration(days: 10)),
      ),
    ];
    _balances = [
      OutstandingBalance(
        balanceId: 'balance-0000-4000-8000-000000000212',
        profileId: _profileId,
        chargeId: _charges.first.chargeId,
        amountCents: 300,
        dueAt: now.subtract(const Duration(days: 9)),
        status: OutstandingBalanceStatus.open,
        createdAt: now.subtract(const Duration(days: 9)),
      ),
      OutstandingBalance(
        balanceId: 'balance-0000-4000-8000-000000000211',
        profileId: _profileId,
        chargeId: 'charge-0000-4000-8000-000000000201',
        amountCents: 500,
        dueAt: now.subtract(const Duration(days: 10)),
        status: OutstandingBalanceStatus.open,
        createdAt: now.subtract(const Duration(days: 10)),
      ),
    ];
    _refunds = [
      Refund(
        refundId: 'refund-0000-4000-8000-000000000301',
        paymentId: 'payment-0000-4000-8000-000000000081',
        amountCents: 200,
        reason: 'Customer request',
        status: RefundStatus.completed,
        providerOperationRef: 'demo-refund-001',
        requestedAt: now.subtract(const Duration(days: 5)),
        completedAt: now.subtract(const Duration(days: 5)),
      ),
    ];
    _documents = [
      BillingDocument(
        documentId: 'document-0000-4000-8000-000000000401',
        paymentId: 'payment-0000-4000-8000-000000000085',
        documentType: BillingDocumentType.electronicInvoice,
        documentNumber: '00000001',
        series: 'B001',
        legalName: 'Lima Parking Operations S.A.C.',
        taxData: const {
          'document_type': 'RUC',
          'document_number': '20608765431',
        },
        issuedAt: now.subtract(const Duration(days: 12)),
        status: BillingDocumentStatus.issued,
      ),
    ];
    _attempts = [
      PaymentAttempt(
        attemptId: 'attempt-0000-4000-8000-000000000501',
        paymentId: 'payment-0000-4000-8000-000000000085',
        attemptNumber: 1,
        startedAt: now.subtract(const Duration(days: 12)),
        finishedAt: now.subtract(const Duration(days: 12)),
        status: 'SUCCESS',
      ),
    ];
  }

  PaymentToken _token(String tokenId) {
    final token = _tokens.where((t) => t.tokenId == tokenId).firstOrNull;
    if (token == null) {
      throw const BillingException('Payment token not found', status: 404);
    }
    return token;
  }

  DigitalPayment _payment(String paymentId) {
    final payment = _payments
        .where((p) => p.paymentId == paymentId)
        .firstOrNull;
    if (payment == null) {
      throw const BillingException('Payment not found', status: 404);
    }
    return payment;
  }

  DigitalPayment _copyPayment(
    DigitalPayment payment, {
    PaymentStatus? status,
  }) => DigitalPayment(
    paymentId: payment.paymentId,
    tokenId: payment.tokenId,
    profileId: payment.profileId,
    operationType: payment.operationType,
    amountCents: payment.amountCents,
    currency: payment.currency,
    status: status ?? payment.status,
    providerOperationRef: payment.providerOperationRef,
    idempotencyKey: payment.idempotencyKey,
    requestHash: payment.requestHash,
    firstSeenAt: payment.firstSeenAt,
    lastSeenAt: _clock(),
    resultReference: payment.resultReference,
    createdAt: payment.createdAt,
    approvedAt: status == PaymentStatus.approved
        ? _clock()
        : payment.approvedAt,
  );

  void _replace(DigitalPayment payment) {
    final index = _payments.indexWhere((p) => p.paymentId == payment.paymentId);
    _payments[index] = payment;
  }

  void _applyApprovedPayment(DigitalPayment payment) {
    if (payment.operationType != PaymentOperationType.subscription ||
        _subscriptions.any(
          (subscription) => subscription.paymentId == payment.paymentId,
        )) {
      return;
    }

    final plan = _plans
        .where((candidate) => candidate.code == payment.providerOperationRef)
        .firstOrNull;
    if (plan == null) return;

    final now = _clock();
    final tenantId = _subscriptions
        .map((subscription) => subscription.tenantId)
        .whereType<String>()
        .firstOrNull;
    for (var index = 0; index < _subscriptions.length; index++) {
      final current = _subscriptions[index];
      if (current.status == SubscriptionStatus.active) {
        _subscriptions[index] = Subscription(
          subscriptionId: current.subscriptionId,
          profileId: current.profileId,
          tenantId: current.tenantId,
          paymentId: current.paymentId,
          plan: current.plan,
          startAt: current.startAt,
          endAt: now,
          status: SubscriptionStatus.expired,
        );
      }
    }
    _subscriptions.insert(
      0,
      Subscription(
        subscriptionId: _nextId('subscription'),
        profileId: payment.profileId,
        tenantId: plan.isDriverPlan ? null : tenantId,
        paymentId: payment.paymentId,
        plan: plan,
        startAt: now,
        endAt: now.add(Duration(days: 30 * plan.billingPeriodMonths)),
        status: SubscriptionStatus.active,
      ),
    );
  }

  String _lastFourOf(DigitalPayment payment) =>
      _tokens
          .where((t) => t.tokenId == payment.tokenId)
          .map((t) => t.lastFour)
          .firstOrNull ??
      '';

  void _resolveLater(DigitalPayment payment) {
    if (_processed.contains(payment.paymentId)) return;
    _processed.add(payment.paymentId);
    final lastFour = _lastFourOf(payment);
    if (lastFour == '1111') return; // stays PENDING for ever
    if (lastFour == '0000') return; // rejected synchronously below
    Future<void>.delayed(paymentResolutionDelay, () {
      final current = _payment(payment.paymentId);
      if (current.status == PaymentStatus.pending) {
        final approved = _copyPayment(current, status: PaymentStatus.approved);
        _replace(approved);
        _applyApprovedPayment(approved);
      }
    });
  }

  // ── Payment tokens ────────────────────────────────────────────────────

  @override
  Future<List<PaymentToken>> listTokens() async {
    await _delay();
    _checkProfile();
    return List.unmodifiable(_tokens);
  }

  @override
  Future<PaymentToken> createToken(String providerTokenRef) async {
    await _delay();
    _checkProfile();
    if (!RegExp(r'^simulated-(visa|mastercard|amex|discover)-[0-9]{4}$')
        .hasMatch(providerTokenRef)) {
      throw const BillingException(
        'Use a synthetic token such as simulated-visa-4242. '
        'Card numbers and security codes are not accepted.',
        status: 400,
      );
    }
    final parts = providerTokenRef.split('-');
    final token = PaymentToken(
      tokenId: _nextId('token'),
      profileId: _profileId,
      brand: parts[2].toUpperCase(),
      lastFour: parts[3],
      expirationMonth: 12,
      expirationYear: _clock().year + 4,
      status: PaymentTokenStatus.active,
      isDefault: _tokens.isEmpty,
      createdAt: _clock(),
    );
    _tokens.add(token);
    return token;
  }

  @override
  Future<PaymentToken> setDefaultToken(String tokenId) async {
    await _delay();
    _checkProfile();
    _token(tokenId);
    final index = _tokens.indexWhere((t) => t.tokenId == tokenId);
    for (var i = 0; i < _tokens.length; i++) {
      final token = _tokens[i];
      _tokens[i] = PaymentToken(
        tokenId: token.tokenId,
        profileId: token.profileId,
        brand: token.brand,
        lastFour: token.lastFour,
        expirationMonth: token.expirationMonth,
        expirationYear: token.expirationYear,
        status: token.status,
        isDefault: i == index,
        createdAt: token.createdAt,
        revokedAt: token.revokedAt,
      );
    }
    return _tokens[index];
  }

  @override
  Future<PaymentToken> revokeToken(String tokenId) async {
    await _delay();
    _checkProfile();
    final token = _token(tokenId);
    final revoked = PaymentToken(
      tokenId: token.tokenId,
      profileId: token.profileId,
      brand: token.brand,
      lastFour: token.lastFour,
      expirationMonth: token.expirationMonth,
      expirationYear: token.expirationYear,
      status: PaymentTokenStatus.revoked,
      isDefault: false,
      createdAt: token.createdAt,
      revokedAt: _clock(),
    );
    _tokens[_tokens.indexWhere((t) => t.tokenId == tokenId)] = revoked;
    return revoked;
  }

  // ── Digital payments ──────────────────────────────────────────────────

  @override
  Future<List<DigitalPayment>> listPayments() async {
    await _delay();
    _checkProfile();
    // PAY-01 answers "mis pagos": only this account's operations. A driver's
    // reservation payment stays reachable through PAY-02 by id, which is how
    // the refund flow reads it.
    return List.unmodifiable(
      _payments.where((payment) => payment.profileId == _profileId),
    );
  }

  @override
  Future<DigitalPayment> getPayment(String paymentId) async {
    await _delay();
    _checkProfile();
    final payment = _payment(paymentId);
    final pendingSince = _pendingSince[paymentId];
    if (payment.status == PaymentStatus.pending &&
        pendingSince != null &&
        _lastFourOf(payment) != '1111' &&
        _clock().difference(pendingSince) >= paymentResolutionDelay) {
      final approved = _copyPayment(payment, status: PaymentStatus.approved);
      _replace(approved);
      _applyApprovedPayment(approved);
      return approved;
    }
    return payment;
  }

  DigitalPayment _initiate({
    required PaymentOperationType operationType,
    required int amountCents,
    required String tokenId,
    required String idempotencyKey,
    String? providerOperationRef,
  }) {
    final token = _token(tokenId);
    if (token.status != PaymentTokenStatus.active) {
      throw _conflict('Payment token is revoked or expired.');
    }
    final signature = '$operationType:$amountCents:$tokenId';
    final previous = _idempotency[idempotencyKey];
    if (previous != null) {
      if (previous == signature) {
        // Replaying the same operation must return the same payment.
        final replay = _payments
            .where((p) => p.idempotencyKey == idempotencyKey)
            .firstOrNull;
        if (replay != null) return replay;
      } else {
        throw _conflict(
          'This idempotency key has already been used with a different request.',
        );
      }
    }
    _idempotency[idempotencyKey] = signature;
    final payment = DigitalPayment(
      paymentId: _nextId('payment'),
      tokenId: tokenId,
      profileId: _profileId,
      operationType: operationType,
      amountCents: amountCents,
      currency: 'PEN',
      status: PaymentStatus.initiated,
      providerOperationRef: providerOperationRef,
      idempotencyKey: idempotencyKey,
      requestHash: idempotencyKey.hashCode.toRadixString(16),
      firstSeenAt: _clock(),
      lastSeenAt: _clock(),
      createdAt: _clock(),
    );
    _payments.add(payment);
    return payment;
  }

  @override
  Future<DigitalPayment> createSubscriptionPayment({
    required String planCode,
    required String tokenId,
    required String idempotencyKey,
  }) async {
    await _delay();
    _checkProfile();
    final plan = _plans.where((p) => p.code == planCode).firstOrNull;
    if (plan == null) {
      throw const BillingException(
        'Plan is not configured in the server catalog.',
        status: 400,
      );
    }
    // SUB-03/PAY-05 answer 403 for a plan of another audience.
    if (!plan.isParkingAdminPlan) {
      throw BillingException(
        'The plan $planCode belongs to another audience; '
        '${RoleGuard.appRole} accounts cannot subscribe to it.',
        status: 403,
      );
    }
    final quotedPlan = _quotedPlan(plan);
    final amountCents = quotedPlan.priceCents;
    if (amountCents == null || amountCents < 1) {
      throw const BillingException(
        'The plan quote did not include a valid total price.',
        status: 400,
      );
    }
    return _initiate(
      operationType: PaymentOperationType.subscription,
      amountCents: amountCents,
      tokenId: tokenId,
      idempotencyKey: idempotencyKey,
      providerOperationRef: planCode,
    );
  }

  @override
  Future<DigitalPayment> processPayment(String paymentId) async {
    await _delay();
    _checkProfile();
    final payment = _payment(paymentId);
    if (payment.status == PaymentStatus.approved) return payment;
    if (payment.status == PaymentStatus.reconciliationRequired ||
        payment.status == PaymentStatus.rejected ||
        payment.status == PaymentStatus.cancelled) {
      throw _conflict(
        'The payment result is unknown. Reconcile it instead of submitting '
        'another charge.',
      );
    }
    if (payment.status == PaymentStatus.pending) return payment;
    final lastFour = _lastFourOf(payment);
    final status = lastFour == '0000'
        ? PaymentStatus.rejected
        : PaymentStatus.pending;
    if (status == PaymentStatus.rejected) {
      // PAY-08 only becomes available 60 seconds after the failure.
      _retryBlockedUntil[paymentId] = _clock().add(const Duration(seconds: 60));
    }
    final processed = _copyPayment(payment, status: status);
    _replace(processed);
    _pendingSince[paymentId] = _clock();
    _resolveLater(processed);
    return processed;
  }

  @override
  Future<DigitalPayment> retryPayment(
    String paymentId, {
    String? tokenId,
  }) async {
    await _delay();
    _checkProfile();
    final payment = _payment(paymentId);
    final blockedUntil = _retryBlockedUntil[paymentId];
    if (blockedUntil != null && _clock().isBefore(blockedUntil)) {
      throw _conflict('The retry is not available yet.');
    }
    if (tokenId != null) _token(tokenId);
    final retried = DigitalPayment(
      paymentId: payment.paymentId,
      tokenId: tokenId ?? payment.tokenId,
      profileId: payment.profileId,
      operationType: payment.operationType,
      amountCents: payment.amountCents,
      currency: payment.currency,
      status: PaymentStatus.initiated,
      providerOperationRef: payment.providerOperationRef,
      idempotencyKey: payment.idempotencyKey,
      requestHash: payment.requestHash,
      firstSeenAt: payment.firstSeenAt,
      lastSeenAt: _clock(),
      createdAt: payment.createdAt,
    );
    _replace(retried);
    _processed.remove(paymentId);
    _retryBlockedUntil.remove(paymentId);
    _pendingSince.remove(paymentId);
    return retried;
  }

  @override
  Future<DigitalPayment> reconcilePayment(String paymentId) async {
    await _delay();
    _checkProfile();
    final payment = _payment(paymentId);
    if (payment.status != PaymentStatus.pending) return payment;
    final status = _lastFourOf(payment) == '1111'
        ? PaymentStatus.reconciliationRequired
        : PaymentStatus.approved;
    final reconciled = _copyPayment(payment, status: status);
    _replace(reconciled);
    if (status == PaymentStatus.approved) _applyApprovedPayment(reconciled);
    return reconciled;
  }

  @override
  Future<List<PaymentAttempt>> listAttempts(String paymentId) async {
    await _delay();
    _checkProfile();
    _payment(paymentId);
    return List.unmodifiable(_attempts.where((a) => a.paymentId == paymentId));
  }

  // ── Subscriptions ─────────────────────────────────────────────────────

  /// SUB-02 is unfiltered in the backend: DRIVER plans really are listed.
  /// They are dropped here so this app only ever offers what PA can buy.
  @override
  Future<List<SubscriptionPlan>> listPlans() async {
    await _delay();
    _checkProfile();
    return List.unmodifiable(_plans.where((plan) => plan.isParkingAdminPlan));
  }

  @override
  Future<SubscriptionPlan> quotePlan(String planCode) async {
    await _delay();
    _checkProfile();
    final plan = _plans.where((p) => p.code == planCode).firstOrNull;
    if (plan == null) {
      throw const BillingException(
        'Plan is not configured in the server catalog.',
        status: 400,
      );
    }
    // SUB-03 answers 403 "plan de otra audiencia".
    if (!plan.isParkingAdminPlan) {
      throw BillingException(
        'The plan $planCode belongs to another audience; '
        '${RoleGuard.appRole} accounts cannot subscribe to it.',
        status: 403,
      );
    }
    return _quotedPlan(plan);
  }

  SubscriptionPlan _quotedPlan(SubscriptionPlan plan) {
    final configuredPrice = plan.priceCents;
    if (configuredPrice != null) {
      if (configuredPrice < 1) {
        throw const BillingException(
          'The plan quote did not include a valid total price.',
          status: 400,
        );
      }
      return plan;
    }
    final deviceCount = plan.parkingSpotCount ?? plan.includedSensors;
    final appUsagePriceCents = plan.appUsagePriceCents;
    final pricePerDeviceCents = plan.pricePerIotDeviceCents;
    if (deviceCount == null ||
        appUsagePriceCents == null ||
        pricePerDeviceCents == null) {
      throw const BillingException(
        'The plan quote cannot be calculated from the mock catalog.',
        status: 400,
      );
    }
    final totalPriceCents =
        appUsagePriceCents + pricePerDeviceCents * deviceCount;
    if (totalPriceCents < 1) {
      throw const BillingException(
        'The plan quote did not include a valid total price.',
        status: 400,
      );
    }
    return SubscriptionPlan(
      code: plan.code,
      audience: plan.audience,
      billingPeriodMonths: plan.billingPeriodMonths,
      priceCents: totalPriceCents,
      discountPercent: plan.discountPercent,
      appUsagePriceCents: plan.appUsagePriceCents,
      pricePerIotDeviceCents: plan.pricePerIotDeviceCents,
      includedSensors: plan.includedSensors,
      licensedSpotIds: plan.licensedSpotIds,
      parkingSpotCount: plan.parkingSpotCount,
    );
  }

  @override
  Future<List<Subscription>> listSubscriptions() async {
    await _delay();
    _checkProfile();
    return List.unmodifiable(_subscriptions);
  }

  @override
  Future<Subscription> cancelSubscription(String subscriptionId) async {
    await _delay();
    _checkProfile();
    final index = _subscriptions.indexWhere(
      (s) => s.subscriptionId == subscriptionId,
    );
    if (index < 0) {
      throw const BillingException('Subscription not found', status: 404);
    }
    final subscription = _subscriptions[index];
    if (subscription.status != SubscriptionStatus.active) {
      throw _conflict('The subscription is no longer active.');
    }
    final cancelled = Subscription(
      subscriptionId: subscription.subscriptionId,
      profileId: subscription.profileId,
      tenantId: subscription.tenantId,
      paymentId: subscription.paymentId,
      plan: subscription.plan,
      startAt: subscription.startAt,
      endAt: subscription.endAt,
      status: SubscriptionStatus.cancelled,
    );
    _subscriptions[index] = cancelled;
    return cancelled;
  }

  // ── Additional charges ────────────────────────────────────────────────

  @override
  Future<List<AdditionalCharge>> listCharges() async {
    await _delay();
    _checkProfile();
    return List.unmodifiable(_charges);
  }

  @override
  Future<AdditionalCharge> createCharge({
    required String reservationId,
    required int amountCents,
    required String reason,
    required String evidenceRef,
  }) async {
    await _delay();
    _checkProfile();
    if (amountCents < 1) {
      throw const BillingException('amount must be at least 0.01', status: 400);
    }
    final charge = AdditionalCharge(
      chargeId: _nextId('charge'),
      reservationId: reservationId,
      amountCents: amountCents,
      reason: reason,
      evidenceRef: evidenceRef,
      status: AdditionalChargeStatus.pending,
      createdAt: _clock(),
    );
    _charges.add(charge);
    return charge;
  }

  @override
  Future<OutstandingBalance> markChargeUnpaid(String chargeId) async {
    await _delay();
    _checkProfile();
    final index = _charges.indexWhere((c) => c.chargeId == chargeId);
    if (index < 0) {
      throw const BillingException('Additional charge not found', status: 404);
    }
    final charge = _charges[index];
    if (charge.status == AdditionalChargeStatus.paid) {
      throw _conflict('The charge has already been paid.');
    }
    if (charge.paymentId != null) {
      throw _conflict(
        'Wait for a final payment result before recording the balance '
        'as unpaid.',
      );
    }
    final existingBalance = _balances
        .where((balance) => balance.chargeId == chargeId)
        .firstOrNull;
    if (existingBalance != null) return existingBalance;
    final balance = OutstandingBalance(
      balanceId: _nextId('balance'),
      profileId: _profileId,
      chargeId: charge.chargeId,
      amountCents: charge.amountCents,
      dueAt: _clock(),
      status: OutstandingBalanceStatus.open,
      createdAt: _clock(),
    );
    _balances.add(balance);
    return balance;
  }

  // ── Outstanding balances ──────────────────────────────────────────────

  @override
  Future<List<OutstandingBalance>> listBalances() async {
    await _delay();
    _checkProfile();
    return List.unmodifiable(_balances);
  }

  @override
  Future<int> totalBalanceCents() async {
    await _delay();
    _checkProfile();
    return _balances
        .where((b) => b.status == OutstandingBalanceStatus.open)
        .fold<int>(0, (total, b) => total + b.amountCents);
  }

  // ── Refunds ──────────────────────────────────────────────────────────

  @override
  Future<List<Refund>> listRefunds(String paymentId) async {
    await _delay();
    _checkProfile();
    return List.unmodifiable(_refunds.where((r) => r.paymentId == paymentId));
  }

  @override
  Future<Refund> requestRefund({
    required String paymentId,
    required int amountCents,
    required String reason,
  }) async {
    await _delay();
    _checkProfile();
    final payment = _payment(paymentId);
    if (payment.status != PaymentStatus.approved) {
      throw _conflict('The refund requires an approved payment.');
    }
    // REF-02: at least 0.01 and never more than what is left unrefunded.
    final remaining = refundableCents(
      payment,
      _refunds.where((refund) => refund.paymentId == paymentId),
    );
    if (amountCents < 1 || amountCents > remaining) {
      throw _conflict('The refund amount is not valid for this payment.');
    }
    final refund = Refund(
      refundId: _nextId('refund'),
      paymentId: paymentId,
      amountCents: amountCents,
      reason: reason,
      status: RefundStatus.requested,
      requestedAt: _clock(),
    );
    _refunds.add(refund);
    return refund;
  }

  @override
  Future<Refund> processRefund(String refundId) async {
    await _delay();
    _checkProfile();
    final index = _refunds.indexWhere((r) => r.refundId == refundId);
    if (index < 0) {
      throw const BillingException('Refund not found', status: 404);
    }
    final refund = _refunds[index];
    if (refund.status == RefundStatus.completed) return refund;
    final processed = Refund(
      refundId: refund.refundId,
      paymentId: refund.paymentId,
      amountCents: refund.amountCents,
      reason: refund.reason,
      status: RefundStatus.completed,
      providerOperationRef: refund.providerOperationRef,
      requestedAt: refund.requestedAt,
      completedAt: _clock(),
    );
    _refunds[index] = processed;
    return processed;
  }

  // ── Billing documents ────────────────────────────────────────────────

  @override
  Future<BillingDocument?> documentForPayment(String paymentId) async {
    await _delay();
    _checkProfile();
    return _documents.where((d) => d.paymentId == paymentId).firstOrNull;
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
  }) async {
    await _delay();
    _checkProfile();
    _payment(paymentId);
    final expectedDigits = documentType == 'ELECTRONIC_INVOICE' ? 11 : 8;
    if (taxDataNumber.length != expectedDigits ||
        !RegExp(r'^[0-9]+$').hasMatch(taxDataNumber)) {
      throw const BillingException(
        'Tax information does not match the billing document type.',
        status: 400,
      );
    }
    if (_documents.any(
      (d) =>
          d.paymentId == paymentId && d.status != BillingDocumentStatus.voided,
    )) {
      throw _conflict(
        'A different billing document is already registered for this payment.',
      );
    }
    if (_documents.any(
      (d) => d.series == series && d.documentNumber == documentNumber,
    )) {
      throw _conflict('The series and document number are already in use.');
    }
    final document = BillingDocument(
      documentId: _nextId('document'),
      paymentId: paymentId,
      documentType: BillingDocumentType.parse(documentType),
      documentNumber: documentNumber,
      series: series,
      legalName: legalName,
      taxData: {'document_type': taxDataType, 'document_number': taxDataNumber},
      issuedAt: _clock(),
      status: BillingDocumentStatus.issued,
    );
    _documents.add(document);
    return document;
  }

  @override
  Future<BillingDocument> voidDocument(String documentId) async {
    await _delay();
    _checkProfile();
    final index = _documents.indexWhere((d) => d.documentId == documentId);
    if (index < 0) {
      throw const BillingException('Billing document not found', status: 404);
    }
    final document = _documents[index];
    if (document.status == BillingDocumentStatus.voided) return document;
    final voided = BillingDocument(
      documentId: document.documentId,
      paymentId: document.paymentId,
      documentType: document.documentType,
      documentNumber: document.documentNumber,
      series: document.series,
      legalName: document.legalName,
      taxData: document.taxData,
      issuedAt: document.issuedAt,
      status: BillingDocumentStatus.voided,
    );
    _documents[index] = voided;
    return voided;
  }
}
