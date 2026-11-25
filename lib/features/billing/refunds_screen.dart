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
import '../../data/models/refund.dart';
import '../../data/repositories/billing_repository.dart';
import '../../state/billing_controller.dart';
import 'billing_widgets.dart';

/// Refunds of one payment (contract REF-01) with the request form (REF-02)
/// and the processing action (REF-03), both Parking Admin operations.
class RefundsScreen extends StatefulWidget {
  const RefundsScreen({super.key, this.paymentId});

  /// Preselected payment, used when the screen is opened from a payment.
  final String? paymentId;

  @override
  State<RefundsScreen> createState() => _RefundsScreenState();
}

class _RefundsScreenState extends State<RefundsScreen> {
  bool _requested = false;
  bool _busy = false;
  String? _error;
  String? _selected;
  String? _forPayment;
  Future<List<Refund>>? _pending;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    _selected = widget.paymentId;
    final billing = AppScope.of(context).billing;
    if (!billing.loaded && !billing.loading) billing.load();
  }

  BillingController get _billing => AppScope.of(context).billing;

  /// Memoizes the list for the selected payment; `null` clears the cache so
  /// the next build fetches again.
  Future<List<Refund>> _ensure(String paymentId) {
    if (_forPayment != paymentId || _pending == null) {
      _forPayment = paymentId;
      _pending = _billing.refundsFor(paymentId);
    }
    return _pending!;
  }

  void _invalidate() {
    _pending = null;
    _forPayment = null;
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      _invalidate();
    } on BillingException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestRefund(DigitalPayment payment) {
    return _act(() async {
      final result = await showDialog<_RefundDraft>(
        context: context,
        builder: (dialogContext) => _RequestRefundDialog(payment: payment),
      );
      if (result == null) return;
      await _billing.requestRefund(
        paymentId: payment.paymentId,
        amountCents: result.amountCents,
        reason: result.reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Refund requested')),
        );
      }
    });
  }

  Future<void> _process(Refund refund) =>
      _act(() => _billing.processRefund(refund.refundId));

  @override
  Widget build(BuildContext context) {
    final billing = _billing;

    return ListenableBuilder(
      listenable: billing,
      builder: (context, _) {
        final approved = [
          for (final payment in billing.payments)
            if (payment.status == PaymentStatus.approved) payment,
        ];
        final selectedId =
            _selected ?? (approved.isEmpty ? null : approved.first.paymentId);
        final payment = billing.paymentById(selectedId ?? '');

        return BillingPage(
          title: 'Refunds',
          subtitle: 'Return an approved payment, then process it',
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
              SectionTitle('Payment'),
              if (approved.isEmpty)
                const Card(
                  child: EmptyView(
                    icon: Icons.block,
                    title: 'No approved payments',
                    message: 'Only an approved payment can be refunded.',
                  ),
                )
              else ...[
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: DropdownButtonFormField<String>(
                      key: const Key('refund-payment'),
                      initialValue: selectedId,
                      decoration: const InputDecoration(
                        labelText: 'Approved payment',
                        border: InputBorder.none,
                      ),
                      items: [
                        for (final item in approved)
                          DropdownMenuItem(
                            value: item.paymentId,
                            child: Text(
                              '${item.operationType.label} · '
                              '${money(item.amountCents)} · '
                              '${Formatters.date(item.createdAt)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() {
                                _selected = value;
                                _invalidate();
                              }),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (payment != null)
                  SectionTitle(
                    'Refunds',
                    trailing: TextButton.icon(
                      key: const Key('refund-new'),
                      onPressed: _busy ? null : () => _requestRefund(payment),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Request'),
                    ),
                  ),
                if (selectedId == null)
                  const Card(
                    child: EmptyView(
                      title: 'Select a payment',
                      message: 'Pick the payment you want to refund.',
                    ),
                  )
                else
                  FutureBuilder<List<Refund>>(
                    future: _ensure(selectedId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Card(
                          child: LoadingView(message: 'Loading refunds...'),
                        );
                      }
                      if (snapshot.hasError) {
                        return Card(
                          child: ErrorView(
                            message: '${snapshot.error}',
                            onRetry: () => setState(_invalidate),
                          ),
                        );
                      }
                      final refunds = snapshot.data ?? const <Refund>[];
                      if (refunds.isEmpty) {
                        return const Card(
                          child: EmptyView(
                            icon: Icons.replay_outlined,
                            title: 'No refunds',
                            message:
                                'Request one from an approved payment to see '
                                'it here.',
                          ),
                        );
                      }
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (final refund in refunds)
                              _RefundTile(
                                refund: refund,
                                busy: _busy,
                                onProcess: refund.status ==
                                            RefundStatus.requested ||
                                        refund.status ==
                                            RefundStatus.processing ||
                                        refund.status ==
                                            RefundStatus.reconciliationRequired
                                    ? () => _process(refund)
                                    : null,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
              const SizedBox(height: 16),
              const NoticeCard(
                icon: Icons.info_outline,
                title: 'How a refund moves',
                message:
                    'A refund starts as REQUESTED, passes through PROCESSING '
                    'and finishes COMPLETED. If the provider does not answer, '
                    'it stays in review until it is reconciled. No real money '
                    'moves in the simulator.',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RefundTile extends StatelessWidget {
  const _RefundTile({
    required this.refund,
    required this.busy,
    this.onProcess,
  });

  final Refund refund;
  final bool busy;
  final VoidCallback? onProcess;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  money(refund.amountCents),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusBadge(label: refund.status.label, tone: refund.status.tone),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            refund.reason,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Requested ${Formatters.dateTime(refund.requestedAt)}'
            '${refund.completedAt == null ? '' : ' · completed ${Formatters.dateTime(refund.completedAt!)}'}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          if (onProcess != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: Key('refund-process-${refund.refundId}'),
              onPressed: busy ? null : onProcess,
              child: const Text('Process refund'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RefundDraft {
  const _RefundDraft({required this.amountCents, required this.reason});

  final int amountCents;
  final String reason;
}

class _RequestRefundDialog extends StatefulWidget {
  const _RequestRefundDialog({required this.payment});

  final DigitalPayment payment;

  @override
  State<_RequestRefundDialog> createState() => _RequestRefundDialogState();
}

class _RequestRefundDialogState extends State<_RequestRefundDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request refund'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment of ${money(widget.payment.amountCents)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('refund-amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (PEN)'),
              validator: (value) {
                final cents = parseCents(value ?? '');
                if (cents == null) return 'Enter an amount greater than 0';
                if (cents > widget.payment.amountCents) {
                  return 'At most ${money(widget.payment.amountCents)}';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('refund-reason'),
              controller: _reason,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Reason'),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Enter a reason' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('refund-submit'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              _RefundDraft(
                amountCents: parseCents(_amount.text)!,
                reason: _reason.text.trim(),
              ),
            );
          },
          child: const Text('Request'),
        ),
      ],
    );
  }
}
