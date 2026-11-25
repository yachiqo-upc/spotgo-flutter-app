import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/billing_types.dart';
import '../../data/models/digital_payment.dart';
import '../../data/models/subscription.dart';
import '../../data/repositories/billing_repository.dart';
import '../../state/billing_controller.dart';
import 'billing_widgets.dart';

/// Plan catalog and the signed in subscription (contract SUB-01, SUB-02,
/// SUB-03, SUB-05) with the subscription payment flow (PAY-05, PAY-07,
/// PAY-09).
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  bool _requested = false;
  bool _busy = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    final billing = AppScope.of(context).billing;
    if (!billing.loaded && !billing.loading) billing.load();
  }

  BillingController get _billing => AppScope.of(context).billing;

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on BillingException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(Subscription subscription) {
    return _act(() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cancel subscription?'),
          content: Text(
            '${subscription.plan.code} stops renewing. The current period is '
            'not refunded automatically.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep it'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cancel subscription'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _billing.cancel(subscription.subscriptionId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Subscription cancelled')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final billing = _billing;

    return ListenableBuilder(
      listenable: billing,
      builder: (context, _) {
        return BillingPage(
          title: 'Plans & subscription',
          subtitle: 'Catalog, quote and current SpotGo subscription',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                BillingErrorBanner(
                  message: _error!,
                  onDismiss: () => setState(() => _error = null),
                )
              else if (billing.error != null)
                BillingErrorBanner(
                  message: billing.error!,
                  onDismiss: billing.clearError,
                ),
              _ActiveSubscription(
                subscription: billing.activeSubscription,
                busy: _busy,
                onCancel: billing.activeSubscription == null
                    ? null
                    : () => _cancel(billing.activeSubscription!),
              ),
              SectionTitle('Available plans'),
              if (billing.loading && billing.plans.isEmpty)
                const Card(child: LoadingView(message: 'Loading plans...'))
              else if (billing.plans.isEmpty)
                const Card(
                  child: EmptyView(
                    icon: Icons.workspace_premium_outlined,
                    title: 'No plans configured',
                    message: 'The server catalog returned no plans.',
                  ),
                )
              else
                for (final plan in billing.plans) ...[
                  _PlanCard(
                    plan: plan,
                    busy: _busy,
                    hasToken: billing.defaultToken != null,
                    onTap: () => _openQuote(plan),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 6),
              if (billing.defaultToken == null)
                const NoticeCard(
                  icon: Icons.credit_card_off_outlined,
                  title: 'Payment method needed',
                  message:
                      'Add a simulated card in Payment methods before '
                      'subscribing.',
                )
              else
                NoticeCard(
                  icon: Icons.shield_outlined,
                  title: 'Simulated charge',
                  message:
                      'The charge runs against ${billing.defaultToken!.maskedNumber} '
                      'and only moves fake money. A token ending in 0000 is '
                      'rejected, one ending in 1111 stays pending.',
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openQuote(SubscriptionPlan plan) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
          ),
          child: SingleChildScrollView(
            child: _QuoteSheet(
              plan: plan,
              busy: _busy,
              hasToken: _billing.defaultToken != null,
              tokenLabel: _billing.defaultToken?.maskedNumber,
              onSubscribe: () async {
                Navigator.of(sheetContext).pop();
                await _subscribe(plan);
              },
            ),
          ),
        ),
      ),
    );
  }

  /// PAY-05 → PAY-07 → poll PAY-02 until the result is final. The
  /// idempotency key is generated once per operation so a retry reuses it.
  Future<void> _subscribe(SubscriptionPlan plan) => _act(() async {
    final token = _billing.defaultToken;
    if (token == null) {
      throw const BillingException(
        'Add a payment method before subscribing.',
        status: 400,
      );
    }
    final quoted = await _billing.quote(plan.code);
    if (!mounted) return;
    final priceCents = quoted.priceCents;
    if (priceCents == null || priceCents <= 0) {
      throw const BillingException(
        'The plan quote did not include a valid total price.',
        status: 400,
      );
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Subscribe to ${quoted.code}'),
        content: Text(
          'Charge of ${money(priceCents)} to ${token.maskedNumber} for '
          '${quoted.billingPeriodMonths} '
          '${quoted.billingPeriodMonths == 1 ? 'month' : 'months'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final idempotencyKey = _billing.newIdempotencyKey(prefix: 'sub');
    var payment = await _billing.createSubscriptionPayment(
      planCode: quoted.code,
      tokenId: token.tokenId,
      idempotencyKey: idempotencyKey,
    );
    payment = await _billing.process(payment.paymentId);
    payment = await _billing.waitForPayment(
      payment.paymentId,
      interval: const Duration(seconds: 1),
      timeout: const Duration(seconds: 20),
      shouldStop: () => !mounted,
    );
    await _billing.refresh();
    if (!mounted) return;
    await _showResult(payment);
  });

  Future<void> _showResult(DigitalPayment payment) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Payment ${payment.status.label.toLowerCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${payment.operationType.label} · ${money(payment.amountCents)}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(switch (payment.status) {
              PaymentStatus.approved =>
                'The subscription is active and the plan was updated.',
              PaymentStatus.rejected =>
                'The provider rejected the charge. You can retry it from '
                    'the payment history once 60 seconds have passed.',
              PaymentStatus.pending =>
                'The provider has not answered yet. Reconcile the payment '
                    'from the payment history.',
              _ => 'Open the payment history to follow this operation.',
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ActiveSubscription extends StatelessWidget {
  const _ActiveSubscription({
    required this.subscription,
    required this.busy,
    this.onCancel,
  });

  final Subscription? subscription;
  final bool busy;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final active = subscription;

    if (active == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No active subscription',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Pick a plan below to activate one for this account.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    active.plan.code,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                StatusBadge(
                  label: active.status.label,
                  tone: active.status.tone,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Started ${Formatters.date(active.startAt)}'
              '${active.endAt == null ? '' : ' · ends ${Formatters.date(active.endAt!)}'}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            if (active.status == SubscriptionStatus.active &&
                onCancel != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('subscription-cancel'),
                onPressed: busy ? null : onCancel,
                child: const Text('Cancel subscription'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.busy,
    required this.hasToken,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final bool busy;
  final bool hasToken;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final period = plan.billingPeriodMonths == 1
        ? 'month'
        : '${plan.billingPeriodMonths} months';
    final price = plan.priceCents == null
        ? 'Quote required'
        : '${money(plan.priceCents!)} / $period';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('plan-${plan.code}'),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.code,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  StatusBadge(
                    label: plan.audience.replaceAll('_', ' '),
                    tone: BadgeTone.info,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                price,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (plan.discountPercent != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${plan.discountPercent}% discount included',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    hasToken
                        ? 'See quote and subscribe'
                        : 'Payment method needed',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quote (SUB-03) of a single plan, with the subscribe action (PAY-05).
class _QuoteSheet extends StatefulWidget {
  const _QuoteSheet({
    required this.plan,
    required this.busy,
    required this.hasToken,
    required this.tokenLabel,
    required this.onSubscribe,
  });

  final SubscriptionPlan plan;
  final bool busy;
  final bool hasToken;
  final String? tokenLabel;
  final VoidCallback onSubscribe;

  @override
  State<_QuoteSheet> createState() => _QuoteSheetState();
}

class _QuoteSheetState extends State<_QuoteSheet> {
  Future<SubscriptionPlan>? _quote;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Built once: a new future on every rebuild would refetch in a loop.
    _quote ??= AppScope.of(context).billing.quote(widget.plan.code);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(plan.code, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          FutureBuilder<SubscriptionPlan>(
            future: _quote,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: LoadingView(message: 'Requesting quote...'),
                );
              }
              if (snapshot.hasError) {
                return ErrorView(message: '${snapshot.error}');
              }
              final quoted = snapshot.data!;
              return SectionCard(
                children: [
                  if (quoted.priceCents != null)
                    InfoRow(
                      title: 'Total',
                      trailing: money(quoted.priceCents!),
                    ),
                  InfoRow(
                    title: 'Billing period',
                    trailing:
                        '${quoted.billingPeriodMonths} '
                        '${quoted.billingPeriodMonths == 1 ? 'month' : 'months'}',
                  ),
                  if (quoted.appUsagePriceCents != null)
                    InfoRow(
                      title: 'App usage',
                      trailing: money(quoted.appUsagePriceCents!),
                    ),
                  if (quoted.pricePerIotDeviceCents != null)
                    InfoRow(
                      title: 'Per IoT device',
                      trailing: money(quoted.pricePerIotDeviceCents!),
                    ),
                  if (quoted.includedSensors != null)
                    InfoRow(
                      title: 'Included sensors',
                      trailing: '${quoted.includedSensors}',
                    ),
                  if (quoted.parkingSpotCount != null)
                    InfoRow(
                      title: 'Parking spots',
                      trailing: '${quoted.parkingSpotCount}',
                    ),
                  if (quoted.licensedSpotIds.isNotEmpty)
                    InfoRow(
                      title: 'Licensed spots',
                      trailing: '${quoted.licensedSpotIds.length}',
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('plan-subscribe'),
            onPressed: widget.busy || !widget.hasToken
                ? null
                : widget.onSubscribe,
            child: Text(
              widget.hasToken
                  ? 'Subscribe with ${widget.tokenLabel}'
                  : 'Add a payment method first',
            ),
          ),
        ],
      ),
    );
  }
}
