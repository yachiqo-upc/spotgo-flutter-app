import 'package:flutter/material.dart';

import '../../app/admin_navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/status_badge.dart';
import '../shell/admin_shell.dart';
import '../shell/account_sheet.dart';
import 'additional_charges_screen.dart';
import 'billing_documents_screen.dart';
import 'edit_billing_screen.dart';
import 'payment_history_screen.dart';
import 'payment_methods_screen.dart';
import 'plans_screen.dart';
import 'refunds_screen.dart';

/// B2B plan, billing details and recent invoices of the business account
/// (mockup 26).
class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: PageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: 'Billing & invoices',
              subtitle: 'Business account · Lima Parking Operations S.A.C.',
              onProfileTap: () => showAccountSheet(context),
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).maybePop()
                  : null,
            ),
            const SectionTitle('Manage billing'),
            SectionCard(
              children: [
                _BillingLink(
                  key: const Key('billing-plans'),
                  title: 'Plans & subscription',
                  subtitle: 'View plans and manage the active subscription',
                  onTap: () => _open(context, const PlansScreen()),
                ),
                _BillingLink(
                  key: const Key('billing-payment-methods'),
                  title: 'Payment methods',
                  subtitle: 'Add, set default or revoke a token',
                  onTap: () => _open(context, const PaymentMethodsScreen()),
                ),
                _BillingLink(
                  key: const Key('billing-payment-history'),
                  title: 'Payment history',
                  subtitle: 'Review payment attempts and status',
                  onTap: () => _open(context, const PaymentHistoryScreen()),
                ),
                _BillingLink(
                  key: const Key('billing-additional-charges'),
                  title: 'Additional charges',
                  subtitle: 'Create charges and review outstanding balances',
                  onTap: () => _open(context, const AdditionalChargesScreen()),
                ),
                _BillingLink(
                  key: const Key('billing-refunds'),
                  title: 'Refunds',
                  subtitle: 'Request and process payment refunds',
                  onTap: () => _open(context, const RefundsScreen()),
                ),
                _BillingLink(
                  key: const Key('billing-documents'),
                  title: 'Billing documents',
                  subtitle: 'Issue receipts and invoices for approved payments',
                  onTap: () => _open(context, const BillingDocumentsScreen()),
                ),
              ],
            ),
            const _PlanCard(),
            const SectionTitle('Billing information'),
            const SectionCard(
              children: [
                InfoRow(
                  title: 'Company / RUC',
                  subtitle: 'Lima Parking Operations S.A.C.',
                  trailing: '20608765431',
                ),
                InfoRow(
                  title: 'Billing email',
                  subtitle: 'facturacion@limaparking.pe',
                  trailingWidget: Text(
                    'Edit',
                    style: TextStyle(color: AppColors.primary, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SectionTitle('Recent invoices'),
            const SectionCard(
              children: [
                InfoRow(
                  title: 'F001-0108',
                  subtitle: '01 Sep 2026 · Paid',
                  trailing: 'S/ 249.00',
                ),
                InfoRow(
                  title: 'F001-0097',
                  subtitle: '01 Aug 2026 · Paid',
                  trailing: 'S/ 249.00',
                ),
                InfoRow(
                  title: 'F001-0086',
                  subtitle: '01 Jul 2026 · Paid',
                  trailing: 'S/ 249.00',
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () =>
                  pushAdminPage<void>(context, const EditBillingScreen()),
              child: const Text('Update billing information'),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(AdminShellState.moreSectionRoute(page));
  }
}

class _BillingLink extends StatelessWidget {
  const _BillingLink({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InfoRow(
    title: title,
    subtitle: subtitle,
    trailingWidget: const Icon(
      Icons.chevron_right,
      color: AppColors.textSecondary,
    ),
    onTap: onTap,
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard();

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
                    'SpotGo Business',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const StatusBadge(label: 'Active', tone: BadgeTone.success),
              ],
            ),
            const SizedBox(height: 10),
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'S/ 249.00',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: ' / month',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Next billing: 01 Oct 2026',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
