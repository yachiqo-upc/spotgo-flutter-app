import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/billing_document.dart';
import '../../data/models/billing_types.dart';
import '../../data/models/digital_payment.dart';
import '../../data/repositories/billing_repository.dart';
import '../../state/billing_controller.dart';
import '../shell/admin_shell.dart';
import 'billing_widgets.dart';
import 'issue_billing_document_screen.dart';

/// Receipts and invoices registered for each payment (contract DOC-01) with
/// the local void action (DOC-03) and a shortcut to the emission form
/// (DOC-02).
class BillingDocumentsScreen extends StatefulWidget {
  const BillingDocumentsScreen({super.key});

  @override
  State<BillingDocumentsScreen> createState() => _BillingDocumentsScreenState();
}

class _BillingDocumentsScreenState extends State<BillingDocumentsScreen> {
  bool _requested = false;
  bool _busy = false;
  String? _error;
  String? _forPayments;
  Future<Map<String, BillingDocument?>>? _documents;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    final billing = AppScope.of(context).billing;
    if (!billing.loaded && !billing.loading) billing.load();
  }

  BillingController get _billing => AppScope.of(context).billing;

  /// One DOC-01 call per payment, cached until the payment list changes.
  Future<Map<String, BillingDocument?>> _ensure(List<DigitalPayment> payments) {
    final key = [for (final payment in payments) payment.paymentId].join(',');
    if (_documents == null || _forPayments != key) {
      _forPayments = key;
      _documents = _load(payments);
    }
    return _documents!;
  }

  Future<Map<String, BillingDocument?>> _load(
    List<DigitalPayment> payments,
  ) async {
    final ids = [for (final payment in payments) payment.paymentId];
    final docs = await Future.wait(ids.map((id) => _billing.documentFor(id)));
    return {for (var i = 0; i < ids.length; i++) ids[i]: docs[i]};
  }

  void _invalidate() {
    _documents = null;
    _forPayments = null;
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
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _void(BillingDocument document) {
    return _act(() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Void document?'),
          content: Text(
            '${document.reference} will be marked as void locally. The '
            'backend keeps the record.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Void document'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _billing.voidDocument(document.documentId);
    });
  }

  Future<void> _openForm({String? paymentId}) async {
    await Navigator.of(context).push(
      AdminShellState.moreSectionRoute(
        IssueBillingDocumentScreen(paymentId: paymentId),
      ),
    );
    if (mounted) setState(_invalidate);
  }

  @override
  Widget build(BuildContext context) {
    final billing = _billing;

    return ListenableBuilder(
      listenable: billing,
      builder: (context, _) {
        final payments = [for (final payment in billing.payments) payment]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final hasApprovedPayments = payments.any(
          (payment) => payment.status == PaymentStatus.approved,
        );

        return BillingPage(
          title: 'Billing documents',
          subtitle: 'Receipts and invoices registered for your payments',
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
                'Documents',
                trailing: TextButton.icon(
                  key: const Key('document-new'),
                  onPressed: _busy || !hasApprovedPayments
                      ? null
                      : () => _openForm(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Issue'),
                ),
              ),
              if (billing.loading && payments.isEmpty)
                const Card(child: LoadingView(message: 'Loading payments...'))
              else if (payments.isEmpty)
                const Card(
                  child: EmptyView(
                    icon: Icons.description_outlined,
                    title: 'No payments to document',
                    message:
                        'Issue a receipt or invoice once a payment is '
                        'approved.',
                  ),
                )
              else
                FutureBuilder<Map<String, BillingDocument?>>(
                  future: _ensure(payments),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Card(
                        child: LoadingView(message: 'Looking up documents...'),
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
                    final documents = snapshot.data ?? const {};
                    return Column(
                      children: [
                        for (final payment in payments) ...[
                          _DocumentCard(
                            payment: payment,
                            document: documents[payment.paymentId],
                            busy: _busy,
                            onIssue: payment.status == PaymentStatus.approved
                                ? () => _openForm(paymentId: payment.paymentId)
                                : null,
                            onVoid:
                                documents[payment.paymentId] == null ||
                                    documents[payment.paymentId]!.status !=
                                        BillingDocumentStatus.issued
                                ? null
                                : () => _void(documents[payment.paymentId]!),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  },
                ),
              const SizedBox(height: 6),
              const NoticeCard(
                icon: Icons.info_outline,
                title: 'Document rules',
                message:
                    'An electronic receipt needs a DNI of 8 digits and an '
                    'electronic invoice a RUC of 11 digits. Series and '
                    'document number are unique, so each payment takes one '
                    'document.',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.payment,
    required this.document,
    required this.busy,
    required this.onIssue,
    this.onVoid,
  });

  final DigitalPayment payment;
  final BillingDocument? document;
  final bool busy;
  final VoidCallback? onIssue;
  final VoidCallback? onVoid;

  @override
  Widget build(BuildContext context) {
    final doc = document;

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
                    money(payment.amountCents),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
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
              '${payment.operationType.label} · '
              '${Formatters.dateTime(payment.createdAt)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            if (doc == null)
              Text(
                payment.status == PaymentStatus.approved
                    ? 'No billing document for this payment.'
                    : 'A document can be issued after payment approval.',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${doc.reference} · ${doc.documentType.label}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  StatusBadge(label: doc.status.label, tone: doc.status.tone),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${doc.legalName} · ${doc.taxNumber}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              Text(
                'Issued ${Formatters.dateTime(doc.issuedAt)}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (doc == null && onIssue != null)
                  OutlinedButton(
                    key: Key('document-issue-${payment.paymentId}'),
                    onPressed: busy ? null : onIssue,
                    child: const Text('Issue document'),
                  ),
                if (onVoid != null)
                  OutlinedButton(
                    key: Key('document-void-${doc!.documentId}'),
                    onPressed: busy ? null : onVoid,
                    child: const Text('Void'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
