import 'package:flutter/material.dart';

import '../../app/admin_navigation.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/page_layout.dart';
import 'account_sheet.dart';
import 'audit_history_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    const chevron = Icon(Icons.chevron_right, color: AppColors.textSecondary);

    return SingleChildScrollView(
      child: PageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: 'More',
              subtitle: '${admin.facilityName} · zone management and records',
              onProfileTap: () => showAccountSheet(context),
            ),
            SectionCard(
              children: [
                InfoRow(
                  key: const Key('more-audit'),
                  title: 'Audit history',
                  subtitle: '${admin.audit.length} administrative changes',
                  trailingWidget: chevron,
                  onTap: () =>
                      pushAdminPage<void>(context, const AuditHistoryScreen()),
                ),
                InfoRow(
                  title: 'Account',
                  subtitle: 'Profile and sign out',
                  trailingWidget: chevron,
                  onTap: () => showAccountSheet(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
