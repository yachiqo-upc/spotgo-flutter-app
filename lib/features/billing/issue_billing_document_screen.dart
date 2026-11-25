import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/widgets/page_layout.dart';
import '../../data/models/billing_types.dart';
import '../../data/repositories/billing_repository.dart';
import 'billing_widgets.dart';

class IssueBillingDocumentScreen extends StatefulWidget {
  const IssueBillingDocumentScreen({super.key, this.paymentId});

  final String? paymentId;

  @override
  State<IssueBillingDocumentScreen> createState() =>
      _IssueBillingDocumentScreenState();
}

class _IssueBillingDocumentScreenState
    extends State<IssueBillingDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _series = TextEditingController(text: 'B001');
  final _documentNumber = TextEditingController();
  final _legalName = TextEditingController();
  final _taxDataNumber = TextEditingController();
  String? _selectedPaymentId;
  BillingDocumentType _type = BillingDocumentType.electronicReceipt;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedPaymentId = widget.paymentId;
  }

  @override
  void dispose() {
    _series.dispose();
    _documentNumber.dispose();
    _legalName.dispose();
    _taxDataNumber.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_busy || !_formKey.currentState!.validate()) return;
    final paymentId = widget.paymentId ?? _selectedPaymentId;
    if (paymentId == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final taxDataType = _type == BillingDocumentType.electronicInvoice
        ? 'RUC'
        : 'DNI';
    try {
      await AppScope.of(context).billing.issueDocument(
        paymentId: paymentId,
        documentType: _type.wire,
        documentNumber: _documentNumber.text.trim(),
        series: _series.text.trim(),
        legalName: _legalName.text.trim(),
        taxDataType: taxDataType,
        taxDataNumber: _taxDataNumber.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } on BillingException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? 'Enter $label' : null;

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context).billing;
    final approvedPayments = billing.payments
        .where((payment) => payment.status == PaymentStatus.approved)
        .toList();
    final isInvoice = _type == BillingDocumentType.electronicInvoice;
    final taxLabel = isInvoice ? 'RUC' : 'DNI';
    final taxDigits = isInvoice ? 11 : 8;

    return Scaffold(
      appBar: AppBar(title: const Text('Issue billing document')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageContainer(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.paymentId != null)
                    Text(
                      'Payment ${widget.paymentId}',
                      style: Theme.of(context).textTheme.titleMedium,
                    )
                  else
                    DropdownButtonFormField<String>(
                      key: const Key('billing-payment-select'),
                      initialValue: _selectedPaymentId,
                      decoration: const InputDecoration(
                        labelText: 'Approved payment',
                      ),
                      items: [
                        for (final payment in approvedPayments)
                          DropdownMenuItem(
                            value: payment.paymentId,
                            child: Text(
                              '${payment.paymentId} · '
                              '${payment.operationType.label}',
                            ),
                          ),
                      ],
                      validator: (value) =>
                          value == null ? 'Select an approved payment' : null,
                      onChanged: _busy
                          ? null
                          : (value) =>
                                setState(() => _selectedPaymentId = value),
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<BillingDocumentType>(
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: 'Document type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: BillingDocumentType.electronicReceipt,
                        child: Text('Electronic receipt'),
                      ),
                      DropdownMenuItem(
                        value: BillingDocumentType.electronicInvoice,
                        child: Text('Electronic invoice'),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              _type = value;
                              _series.text =
                                  value == BillingDocumentType.electronicInvoice
                                  ? 'F001'
                                  : 'B001';
                            });
                          },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _series,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Series',
                          ),
                          validator: (value) => _required(value, 'the series'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _documentNumber,
                          key: const Key('billing-document-number'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Document number',
                          ),
                          validator: (value) =>
                              _required(value, 'the document number'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _legalName,
                    key: const Key('billing-legal-name'),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Legal name'),
                    validator: (value) =>
                        (value == null || value.trim().length < 3)
                        ? 'Enter the legal name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _taxDataNumber,
                    key: const Key('billing-tax-number'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(taxDigits),
                    ],
                    decoration: InputDecoration(
                      labelText: taxLabel,
                      helperText: 'Enter exactly $taxDigits digits',
                    ),
                    validator: (value) =>
                        (value == null ||
                            value.length != taxDigits ||
                            !RegExp(r'^[0-9]+$').hasMatch(value))
                        ? 'Enter a $taxLabel with $taxDigits digits'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  if (_error != null) BillingErrorBanner(message: _error!),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('billing-document-submit'),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Issue document'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
