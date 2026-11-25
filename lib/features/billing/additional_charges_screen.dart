import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/additional_charge.dart';
import '../../data/repositories/billing_repository.dart';
import '../../state/billing_controller.dart';
import 'billing_widgets.dart';

/// Additional charges of the facility (contract CHG-01, CHG-02, CHG-03) and
/// the outstanding balance they can create (BAL-01, BAL-02).
///
/// CHG-02 and CHG-03 are Parking Admin operations, so this screen is only
/// reachable from the Parking Admin area.
class AdditionalChargesScreen extends StatefulWidget {
  const AdditionalChargesScreen({super.key});

  @override
  State<AdditionalChargesScreen> createState() =>
      _AdditionalChargesScreenState();
}

class _AdditionalChargesScreenState extends State<AdditionalChargesScreen> {
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

  Future<void> _createCharge() {
    return _act(() async {
      final draft = await showDialog<_ChargeDraft>(
        context: context,
        builder: (dialogContext) => const _NewChargeDialog(),
      );
      if (draft == null) return;
      await _billing.createCharge(
        reservationId: draft.reservationId,
        amountCents: draft.amountCents,
        reason: draft.reason,
        evidenceRef: draft.evidenceRef,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Additional charge created')),
        );
      }
    });
  }

  Future<void> _markUnpaid(AdditionalCharge charge) {
    return _act(() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Record as outstanding balance?'),
          content: Text(
            '${money(charge.amountCents)} will be registered as an open '
            'balance for this reservation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Record balance'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _billing.markUnpaid(charge.chargeId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Balance recorded')));
      }
    });
  }

  Future<void> _refreshBalance() => _act(_billing.refreshBalance);

  @override
  Widget build(BuildContext context) {
    final billing = _billing;

    return ListenableBuilder(
      listenable: billing,
      builder: (context, _) {
        final charges = [for (final charge in billing.charges) charge]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return BillingPage(
          title: 'Additional charges',
          subtitle: 'Documented charges and the balances they create',
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
              SectionTitle(
                'Outstanding balance',
                trailing: IconButton(
                  tooltip: 'Refresh balance',
                  onPressed: _busy ? null : _refreshBalance,
                  icon: const Icon(Icons.refresh, size: 20),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        money(billing.balanceCents),
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Sum of the OPEN balances of this account (BAL-02).',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const OutlinedButton(
                        key: Key('balance-pay'),
                        onPressed: null,
                        child: Text('Pay balance · por implementar'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const NoticeCard(
                icon: Icons.construction,
                title: 'Balance payment pending',
                message:
                    'Settling an open balance has no Parking Admin endpoint '
                    'in the API contract (§1.5). Drivers settle their own '
                    'balances during checkout; that flow is out of scope for '
                    'this app and stays marked as pending.',
              ),
              SectionTitle(
                'Charges',
                trailing: TextButton.icon(
                  key: const Key('charge-new'),
                  onPressed: _busy ? null : _createCharge,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New charge'),
                ),
              ),
              if (billing.loading && charges.isEmpty)
                const Card(child: LoadingView(message: 'Loading charges...'))
              else if (charges.isEmpty)
                const Card(
                  child: EmptyView(
                    icon: Icons.receipt_long_outlined,
                    title: 'No additional charges',
                    message:
                        'Charge a completed reservation for damage or '
                        'overstay with its evidence reference.',
                  ),
                )
              else
                for (final charge in charges) ...[
                  _ChargeCard(
                    charge: charge,
                    busy: _busy,
                    onMarkUnpaid:
                        charge.canBePaid &&
                            !billing.hasBalanceForCharge(charge.chargeId)
                        ? () => _markUnpaid(charge)
                        : null,
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _ChargeCard extends StatelessWidget {
  const _ChargeCard({
    required this.charge,
    required this.busy,
    this.onMarkUnpaid,
  });

  final AdditionalCharge charge;
  final bool busy;
  final VoidCallback? onMarkUnpaid;

  @override
  Widget build(BuildContext context) {
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
                    money(charge.amountCents),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StatusBadge(
                  label: charge.status.label,
                  tone: charge.status.tone,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              charge.reason,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Reservation ${charge.reservationId}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
            if (charge.evidenceRef.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                'Evidence ${charge.evidenceRef}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Created ${Formatters.date(charge.createdAt)}'
              '${charge.paymentId == null ? '' : ' · paid'}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            if (onMarkUnpaid != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: Key('charge-unpaid-${charge.chargeId}'),
                onPressed: busy ? null : onMarkUnpaid,
                child: const Text('Record as outstanding balance'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChargeDraft {
  const _ChargeDraft({
    required this.reservationId,
    required this.amountCents,
    required this.reason,
    required this.evidenceRef,
  });

  final String reservationId;
  final int amountCents;
  final String reason;
  final String evidenceRef;
}

class _NewChargeDialog extends StatefulWidget {
  const _NewChargeDialog();

  @override
  State<_NewChargeDialog> createState() => _NewChargeDialogState();
}

class _NewChargeDialogState extends State<_NewChargeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reservation = TextEditingController();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _evidence = TextEditingController();

  @override
  void dispose() {
    for (final controller in [_reservation, _amount, _reason, _evidence]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New additional charge'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('charge-reservation'),
                controller: _reservation,
                decoration: const InputDecoration(
                  labelText: 'Reservation ID',
                  hintText: 'UUID of an active, completed or overstay stay',
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter the reservation ID'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('charge-amount'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Amount (PEN)'),
                validator: (value) => parseCents(value ?? '') == null
                    ? 'Enter an amount greater than 0'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('charge-reason'),
                controller: _reason,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Reason'),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter a reason' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('charge-evidence'),
                controller: _evidence,
                decoration: const InputDecoration(
                  labelText: 'Evidence reference',
                  hintText: 'photo-123',
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter the evidence reference'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('charge-submit'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              _ChargeDraft(
                reservationId: _reservation.text.trim(),
                amountCents: parseCents(_amount.text)!,
                reason: _reason.text.trim(),
                evidenceRef: _evidence.text.trim(),
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
