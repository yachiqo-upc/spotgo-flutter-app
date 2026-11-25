import 'package:flutter/material.dart';

import '../../core/widgets/cards.dart';
import '../../core/widgets/page_layout.dart';

/// Edits the billing details used for future B2B invoices (mockup 41).
class EditBillingScreen extends StatefulWidget {
  const EditBillingScreen({super.key});

  @override
  State<EditBillingScreen> createState() => _EditBillingScreenState();
}

class _EditBillingScreenState extends State<EditBillingScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _legalName = TextEditingController(
    text: 'Lima Parking Operations S.A.C.',
  );
  late final _ruc = TextEditingController(text: '20608765431');
  late final _email = TextEditingController(
    text: 'facturacion@limaparking.pe',
  );
  late final _address = TextEditingController(text: 'Av. Javier Prado Oeste 607');
  late final _district = TextEditingController(text: 'San Isidro');
  late final _city = TextEditingController(text: 'Lima');

  @override
  void dispose() {
    for (final c in [_legalName, _ruc, _email, _address, _district, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Billing information saved')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit billing information')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageContainer(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Business billing details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'These details are used for future B2B invoices.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _legalName,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Legal name'),
                    validator: (v) =>
                        (v == null || v.trim().length < 3)
                        ? 'Enter the legal name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _ruc,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'RUC'),
                    validator: (v) =>
                        (v == null || v.trim().length < 6) ? 'Enter the RUC' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Billing email'),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _address,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Fiscal address'),
                    validator: (v) =>
                        (v == null || v.trim().length < 5)
                        ? 'Enter the fiscal address'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _district,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'District'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _city,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(labelText: 'City'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const NoticeCard(
                    title: 'Invoice updates',
                    message:
                        'Changes apply to future invoices. Previously issued '
                        'invoices keep the billing information that was valid '
                        'at issuance.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('billing-save'),
                    onPressed: _save,
                    child: const Text('Save billing information'),
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
