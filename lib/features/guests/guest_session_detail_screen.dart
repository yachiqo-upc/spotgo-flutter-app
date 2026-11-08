import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/choice_chip_bar.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/guest_session.dart';
import '../../domain/parking_rules.dart';
import 'guest_sessions_screen.dart';

/// Guest session details with exit registration and physical payment
/// confirmation (mockup 23, US03 scenarios 3 and 4).
class GuestSessionDetailScreen extends StatefulWidget {
  const GuestSessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<GuestSessionDetailScreen> createState() =>
      _GuestSessionDetailScreenState();
}

class _GuestSessionDetailScreenState extends State<GuestSessionDetailScreen> {
  final _referenceController = TextEditingController();
  final _paymentFormKey = GlobalKey<FormState>();
  PhysicalPaymentMethod _method = PhysicalPaymentMethod.cash;
  bool _collected = false;
  bool _busy = false;
  String? _error;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ParkingRuleException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Operation failed. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _registerExit() => _run(() async {
    await AdminScope.of(context).registerGuestExit(widget.sessionId);
  });

  Future<void> _confirmPayment() async {
    if (!_paymentFormKey.currentState!.validate()) return;
    if (!_collected) {
      setState(() => _error = 'Confirm that the payment was collected.');
      return;
    }
    final admin = AdminScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await _run(() async {
      final session = await admin.confirmGuestPayment(
        widget.sessionId,
        method: _method,
        reference: _referenceController.text,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('Session ${session.id} closed')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final session = admin.sessionById(widget.sessionId);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Guest session details')),
        body: const Center(
          child: EmptyView(
            icon: Icons.search_off,
            title: 'Session not found',
            message: 'Go back and refresh the list.',
          ),
        ),
      );
    }

    final now = admin.now;
    final zone = admin.zoneById(session.zoneId);
    final spot = admin.spotById(session.spotId);
    final (label, tone) = guestStatusBadge(session, now);
    final rate = zone?.ratePerHour ?? 0;
    final fraction = zone?.billingFractionMinutes ?? 60;
    final amount =
        session.amount ??
        ParkingRules.guestAmount(
          entryAt: session.entryAt,
          exitAt: now,
          ratePerHour: rate,
          billingFractionMinutes: fraction,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Guest session details')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.plate,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    StatusBadge(label: label, tone: tone),
                  ],
                ),
                const SizedBox(height: 14),
                SectionCard(
                  children: [
                    InfoRow(
                      title: 'Parking zone',
                      subtitle:
                          '${zone?.name ?? 'Unassigned'} · '
                          '${zone?.district ?? admin.district}',
                      trailing: admin.facilityName,
                    ),
                    InfoRow(
                      title: 'Parking spot',
                      subtitle:
                          '${spot?.type.label ?? 'Unknown'} spot · '
                          'sensor ${spot?.sensorHealth.label.toLowerCase() ?? '-'}',
                      trailing: session.spotCode,
                    ),
                    InfoRow(
                      title: 'Vehicle',
                      subtitle: 'No Driver account · no reservation',
                      trailing: [
                        session.vehicleType.label,
                        if (session.color != null) session.color!,
                      ].join(' · '),
                    ),
                    InfoRow(
                      title: 'Started',
                      subtitle: Formatters.dayAndTime(session.entryAt, now),
                      trailing: Formatters.duration(session.elapsed(now)),
                    ),
                    InfoRow(
                      title: 'Expected checkout',
                      subtitle:
                          '${Formatters.duration(session.expectedDuration)} '
                          '· 5 min tolerance',
                      trailing: Formatters.time(session.expectedCheckout),
                    ),
                    if (session.exitAt != null)
                      InfoRow(
                        title: 'Exit registered',
                        subtitle: Formatters.dayAndTime(session.exitAt!, now),
                        trailing: Formatters.duration(session.elapsed(now)),
                      ),
                    InfoRow(
                      key: const Key('guest-amount'),
                      title: session.exitRegistered
                          ? 'Amount due'
                          : 'Current amount',
                      subtitle:
                          'Rate ${Formatters.money(rate)} per hour · '
                          '$fraction min fraction',
                      trailingWidget: Text(
                        Formatters.money(amount),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (session.status == GuestSessionStatus.pendingReview) ...[
                  const NoticeCard(
                    icon: Icons.sensors_off,
                    message:
                        'Sensor data for this spot is not reliable. No '
                        'automatic charges are applied; confirm the exit and '
                        'payment manually.',
                  ),
                  const SizedBox(height: 12),
                ] else if (session.isOverstay(now)) ...[
                  const NoticeCard(
                    icon: Icons.timer_off_outlined,
                    message:
                        'The expected checkout plus the 5-minute tolerance has '
                        'passed. The amount includes the additional time.',
                  ),
                  const SizedBox(height: 12),
                ],
                if (session.isClosed)
                  _ClosedSummary(session: session)
                else
                  _CheckoutCard(
                    exitRegistered: session.exitRegistered,
                    busy: _busy,
                    error: _error,
                    method: _method,
                    collected: _collected,
                    formKey: _paymentFormKey,
                    referenceController: _referenceController,
                    onMethod: (m) => setState(() => _method = m),
                    onCollected: (v) => setState(() => _collected = v),
                    onRegisterExit: _registerExit,
                    onConfirm: _confirmPayment,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckoutCard extends StatelessWidget {
  const _CheckoutCard({
    required this.exitRegistered,
    required this.busy,
    required this.error,
    required this.method,
    required this.collected,
    required this.formKey,
    required this.referenceController,
    required this.onMethod,
    required this.onCollected,
    required this.onRegisterExit,
    required this.onConfirm,
  });

  final bool exitRegistered;
  final bool busy;
  final String? error;
  final PhysicalPaymentMethod method;
  final bool collected;
  final GlobalKey<FormState> formKey;
  final TextEditingController referenceController;
  final ValueChanged<PhysicalPaymentMethod> onMethod;
  final ValueChanged<bool> onCollected;
  final VoidCallback onRegisterExit;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final progress = busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Check-out & physical payment',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    exitRegistered
                        ? 'Exit recorded. Register the amount collected at the '
                              'exit by cash or external POS to close the session.'
                        : 'End the parking session first. Then register the '
                              'amount collected at the exit by cash or external '
                              'POS.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (exitRegistered) ...[
                    const SizedBox(height: 14),
                    ChoiceChipBar<PhysicalPaymentMethod>(
                      options: [
                        for (final m in PhysicalPaymentMethod.values)
                          ChipOption(m, m.label),
                      ],
                      selected: method,
                      onSelected: onMethod,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('guest-reference'),
                      controller: referenceController,
                      maxLength: 30,
                      decoration: const InputDecoration(
                        labelText: 'Receipt or voucher number',
                        hintText: 'Optional',
                      ),
                      validator: (value) {
                        final compact = (value ?? '').replaceAll(
                          RegExp(r'[\s.-]'),
                          '',
                        );
                        if (RegExp(r'\d{12,19}').hasMatch(compact)) {
                          return 'Do not enter card numbers';
                        }
                        return null;
                      },
                    ),
                    CheckboxListTile(
                      key: const Key('guest-collected'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: collected,
                      onChanged: (v) => onCollected(v ?? false),
                      title: const Text(
                        'Payment collected at the exit',
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: const Text(
                        'SpotGo does not process or store card data.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (error != null) ...[
          Container(
            key: const Key('guest-detail-error'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.dangerMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              error!,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!exitRegistered)
          FilledButton(
            key: const Key('guest-register-exit'),
            onPressed: busy ? null : onRegisterExit,
            child: progress ?? const Text('End session & register exit'),
          )
        else
          FilledButton(
            key: const Key('guest-confirm-payment'),
            onPressed: busy ? null : onConfirm,
            child: progress ?? const Text('Confirm payment & close session'),
          ),
      ],
    );
  }
}

class _ClosedSummary extends StatelessWidget {
  const _ClosedSummary({required this.session});

  final GuestSession session;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      children: [
        InfoRow(
          title: 'Payment confirmed',
          subtitle: session.paymentReference == null
              ? 'Collected at the exit'
              : 'Reference ${session.paymentReference}',
          trailing: session.paymentMethod?.label ?? '-',
        ),
        InfoRow(
          title: 'Session closed',
          subtitle: 'Final amount',
          trailing: Formatters.money(session.amount ?? 0),
        ),
      ],
    );
  }
}
