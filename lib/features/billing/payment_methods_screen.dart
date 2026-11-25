import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/payment_token.dart';
import '../../data/repositories/billing_repository.dart';
import '../../state/billing_controller.dart';
import 'billing_widgets.dart';

/// Saved payment methods of the signed in account (contract TOK-01…04).
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  bool _requested = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    final billing = AppScope.of(context).billing;
    if (!billing.loaded && !billing.loading) billing.load();
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on BillingException {
      // Kept in BillingController.error and rendered by the banner.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addToken(BillingController billing) {
    return _act(() async {
      final reference = await showDialog<String>(
        context: context,
        builder: (dialogContext) => const _AddTokenDialog(),
      );
      if (reference == null) return;
      await billing.addToken(reference);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment method registered')),
      );
    });
  }

  Future<void> _setDefault(BillingController billing, String tokenId) =>
      _act(() => billing.makeDefault(tokenId));

  Future<void> _revoke(BillingController billing, PaymentToken token) {
    return _act(() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Revoke payment method?'),
          content: Text(
            '${token.maskedNumber} will stop being usable for new payments. '
            'Past operations are not affected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Revoke'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await billing.revoke(token.tokenId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context).billing;

    return ListenableBuilder(
      listenable: billing,
      builder: (context, _) {
        return BillingPage(
          title: 'Payment methods',
          subtitle: 'Simulated cards used to pay SpotGo services',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (billing.error != null)
                BillingErrorBanner(
                  message: billing.error!,
                  onDismiss: billing.clearError,
                ),
              if (billing.needsProfile)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: NoticeCard(
                    icon: Icons.person_outline,
                    title: 'Profile required',
                    message:
                        'Create your profile first. The backend answers 404 '
                        'until the account has one.',
                  ),
                ),
              SectionTitle(
                'Saved methods',
                trailing: TextButton.icon(
                  key: const Key('token-add'),
                  onPressed: _busy ? null : () => _addToken(billing),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ),
              if (billing.loading && billing.tokens.isEmpty)
                const Card(child: LoadingView(message: 'Loading methods...'))
              else if (billing.tokens.isEmpty)
                const Card(
                  child: EmptyView(
                    icon: Icons.credit_card_outlined,
                    title: 'No payment methods',
                    message: 'Add a simulated card to pay subscriptions.',
                  ),
                )
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final token in billing.tokens) ...[
                        _TokenTile(
                          token: token,
                          busy: _busy,
                          onMakeDefault: token.isActive && !token.isDefault
                              ? () => _setDefault(billing, token.tokenId)
                              : null,
                          onRevoke: token.isActive
                              ? () => _revoke(billing, token)
                              : null,
                        ),
                        if (token != billing.tokens.last)
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              const NoticeCard(
                icon: Icons.shield_outlined,
                title: 'Simulated payments',
                message:
                    'SpotGo never asks for a real card number or CVV. Use a '
                    'synthetic reference such as simulated-visa-4242. A token '
                    'ending in 0000 is rejected, one ending in 1111 stays '
                    'pending, any other token is approved.',
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Keeps the action helpers readable without repeating the cast at each call.
class _TokenTile extends StatelessWidget {
  const _TokenTile({
    required this.token,
    required this.busy,
    this.onMakeDefault,
    this.onRevoke,
  });

  final PaymentToken token;
  final bool busy;
  final VoidCallback? onMakeDefault;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            token.brand.isEmpty ? Icons.credit_card : Icons.credit_card,
            color: token.isActive ? AppColors.primary : AppColors.textMuted,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        token.maskedNumber,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(
                      label: token.status.label,
                      tone: token.status.tone,
                    ),
                    if (token.isDefault && token.isActive) ...[
                      const SizedBox(width: 6),
                      const StatusBadge(label: 'Default', tone: BadgeTone.info),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Expires ${token.expiration} · added '
                  '${token.createdAt.toLocal().toString().split(' ').first}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (onMakeDefault != null || onRevoke != null)
            PopupMenuButton<String>(
              enabled: !busy,
              tooltip: 'Method actions',
              onSelected: (value) {
                if (value == 'default') onMakeDefault?.call();
                if (value == 'revoke') onRevoke?.call();
              },
              itemBuilder: (menuContext) => [
                if (onMakeDefault != null)
                  const PopupMenuItem(
                    value: 'default',
                    child: Text('Mark as default'),
                  ),
                if (onRevoke != null)
                  const PopupMenuItem(
                    value: 'revoke',
                    child: Text(
                      'Revoke',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AddTokenDialog extends StatefulWidget {
  const _AddTokenDialog();

  @override
  State<_AddTokenDialog> createState() => _AddTokenDialogState();
}

class _AddTokenDialogState extends State<_AddTokenDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static final _pattern = RegExp(
    r'^simulated-(visa|mastercard|amex|discover)-[0-9]{4}$',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add payment method'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              key: const Key('token-reference'),
              controller: _controller,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Synthetic token reference',
                hintText: 'simulated-visa-4242',
              ),
              validator: (value) {
                final ref = (value ?? '').trim();
                if (ref.isEmpty) return 'Enter the reference';
                if (_pattern.hasMatch(ref)) return null;
                return 'Use simulated-(visa|mastercard|amex|discover)-NNNN';
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Real card numbers and security codes are rejected by the '
              'simulator.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
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
          key: const Key('token-submit'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(_controller.text.trim());
          },
          child: const Text('Register'),
        ),
      ],
    );
  }
}
