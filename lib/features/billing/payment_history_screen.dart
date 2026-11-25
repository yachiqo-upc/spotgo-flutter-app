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
import '../../data/repositories/billing_repository.dart';
import '../../state/billing_controller.dart';
import '../shell/admin_shell.dart';
import 'billing_widgets.dart';
import 'issue_billing_document_screen.dart';
import 'refunds_screen.dart';

/// Payment operations of the account (contract PAY-01, PAY-02 and ATT-01).
/// Each row opens a sheet with the attempts and the actions available for
/// the current status: process, retry and reconcile.
class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    final billing = AppScope.of(context).billing;
    if (!billing.loaded && !billing.loading) billing.load();
  }

  Future<void> _refresh(BillingController billing) => billing.refresh();

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context).billing;

    return ListenableBuilder(
      listenable: billing,
      builder: (context, _) {
        final payments = [for (final payment in billing.payments) payment]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return BillingPage(
          title: 'Payment history',
          subtitle: 'Every digital payment, with retries and reconciliation',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (billing.error != null)
                BillingErrorBanner(
                  message: billing.error!,
                  onDismiss: billing.clearError,
                ),
              SectionTitle(
                'Payments',
                trailing: IconButton(
                  tooltip: 'Refresh',
                  onPressed: billing.loading ? null : () => _refresh(billing),
                  icon: const Icon(Icons.refresh, size: 20),
                ),
              ),
              if (billing.loading && payments.isEmpty)
                const Card(child: LoadingView(message: 'Loading payments...'))
              else if (payments.isEmpty)
                const Card(
                  child: EmptyView(
                    icon: Icons.receipt_long_outlined,
                    title: 'No payments yet',
                    message:
                        'Subscriptions, reservations and charges appear here '
                        'once they are paid.',
                  ),
                )
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final payment in payments) ...[
                        _PaymentTile(
                          payment: payment,
                          onTap: () => _openDetail(payment),
                        ),
                        if (payment != payments.last)
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              const NoticeCard(
                icon: Icons.info_outline,
                title: 'Reading a payment',
                message:
                    'Approved and rejected results are final. A payment that '
                    'stays pending must be reconciled with the provider, and '
                    'a rejected one can be retried 60 seconds after the '
                    'failure.',
              ),
            ],
          ),
        );
      },
    );
  }

  void _openDetail(DigitalPayment payment) {
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
            child: _PaymentDetail(paymentId: payment.paymentId),
          ),
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, required this.onTap});

  final DigitalPayment payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('payment-${payment.paymentId}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.operationType.label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${Formatters.dateTime(payment.createdAt)} · '
                    '${payment.currency}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  money(payment.amountCents),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                StatusBadge(
                  label: payment.status.label,
                  tone: payment.status.tone,
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with PAY-02, ATT-01 and the actions valid for the status.
class _PaymentDetail extends StatefulWidget {
  const _PaymentDetail({required this.paymentId});

  final String paymentId;

  @override
  State<_PaymentDetail> createState() => _PaymentDetailState();
}

class _PaymentDetailState extends State<_PaymentDetail> {
  bool _requested = false;
  bool _busy = false;
  String? _actionError;
  List<PaymentAttempt> _attempts = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    _loadAttempts();
  }

  BillingController get _billing => AppScope.of(context).billing;

  Future<void> _loadAttempts() async {
    try {
      final attempts = await _billing.attempts(widget.paymentId);
      if (mounted) setState(() => _attempts = attempts);
    } on BillingException {
      // Attempts are informational; ignore a failure here.
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await action();
      await _loadAttempts();
    } on BillingException catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _process() => _run(() async {
    await _billing.process(widget.paymentId);
    await _billing.waitForPayment(
      widget.paymentId,
      interval: const Duration(seconds: 1),
      timeout: const Duration(seconds: 20),
      shouldStop: () => !mounted,
    );
  });

  Future<void> _reconcile() => _run(() => _billing.reconcile(widget.paymentId));

  Future<void> _retry() => _run(() => _billing.retry(widget.paymentId));

  /// Closes the sheet and pushes [page] on the same More stack, so the
  /// bottom navigation stays visible.
  void _open(Widget page) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(AdminShellState.moreSectionRoute(page));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _billing,
      builder: (context, _) {
        final payment = _billing.paymentById(widget.paymentId);
        if (payment == null) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: LoadingView(message: 'Loading payment...'),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      payment.operationType.label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  StatusBadge(
                    label: payment.status.label,
                    tone: payment.status.tone,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                money(payment.amountCents),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              if (_actionError != null)
                BillingErrorBanner(message: _actionError!),
              SectionCard(
                children: [
                  InfoRow(title: 'Payment ID', subtitle: payment.paymentId),
                  InfoRow(
                    title: 'Idempotency key',
                    subtitle: payment.idempotencyKey,
                  ),
                  if (payment.providerOperationRef != null)
                    InfoRow(
                      title: 'Provider reference',
                      subtitle: payment.providerOperationRef!,
                    ),
                  InfoRow(
                    title: 'Created',
                    subtitle: Formatters.dateTime(payment.createdAt),
                  ),
                  if (payment.approvedAt != null)
                    InfoRow(
                      title: 'Approved',
                      subtitle: Formatters.dateTime(payment.approvedAt!),
                    ),
                ],
              ),
              SectionTitle('Attempts'),
              if (_attempts.isEmpty)
                const Card(
                  child: EmptyView(
                    icon: Icons.hourglass_empty,
                    title: 'No attempts recorded',
                  ),
                )
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final attempt in _attempts)
                        InfoRow(
                          title:
                              'Attempt ${attempt.attemptNumber} · '
                              '${attempt.status}',
                          subtitle:
                              '${Formatters.dateTime(attempt.startedAt)}'
                              '${attempt.errorCode == null ? '' : ' · ${attempt.errorCode}'}',
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              ..._actions(payment),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _actions(DigitalPayment payment) {
    final buttons = <Widget>[];

    if (payment.status == PaymentStatus.initiated) {
      buttons.add(
        FilledButton(
          key: const Key('payment-process'),
          onPressed: _busy ? null : _process,
          child: const Text('Process payment'),
        ),
      );
    }

    if (payment.status == PaymentStatus.pending ||
        payment.status == PaymentStatus.reconciliationRequired) {
      buttons.add(
        FilledButton(
          key: const Key('payment-reconcile'),
          onPressed: _busy ? null : _reconcile,
          child: const Text('Reconcile with provider'),
        ),
      );
    }

    if (payment.status == PaymentStatus.rejected) {
      buttons.add(
        FilledButton(
          key: const Key('payment-retry'),
          onPressed: _busy ? null : _retry,
          child: const Text('Retry payment'),
        ),
      );
      buttons.add(
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: NoticeCard(
            message:
                'A retry is available 60 seconds after the failure. The '
                'backend answers 409 until then.',
          ),
        ),
      );
    }

    if (payment.status == PaymentStatus.approved) {
      buttons.add(
        OutlinedButton(
          key: const Key('payment-refund'),
          onPressed: _busy
              ? null
              : () => _open(RefundsScreen(paymentId: payment.paymentId)),
          child: const Text('Refunds for this payment'),
        ),
      );
      buttons.add(const SizedBox(height: 8));
      buttons.add(
        OutlinedButton(
          key: const Key('payment-document'),
          onPressed: _busy
              ? null
              : () => _open(
                  IssueBillingDocumentScreen(paymentId: payment.paymentId),
                ),
          child: const Text('Issue billing document'),
        ),
      );
    }

    if (buttons.isEmpty) {
      buttons.add(
        const Text(
          'No actions are available for this status.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }

    if (_busy) {
      buttons.add(
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ),
      );
    }

    return buttons;
  }
}
