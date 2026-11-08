import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/cards.dart';

Future<void> showAccountSheet(BuildContext context) {
  final auth = AppScope.of(context).auth;
  final account = auth.account;
  if (account == null) return Future.value();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryMuted,
                  child: Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.fullName,
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                      Text(
                        account.email,
                        style: Theme.of(sheetContext).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
              children: [
                const InfoRow(title: 'Role', trailing: 'Parking Admin'),
                InfoRow(
                  title: 'Assigned facility',
                  subtitle: '${account.facilityName} · ${account.district}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const NoticeCard(
              message:
                  'Account enabled by SuperAdmin. Operational data shown in '
                  'this build is local sample data.',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('sign-out'),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
              onPressed: () {
                Navigator.of(sheetContext).popUntil((route) => route.isFirst);
                auth.signOut();
              },
            ),
          ],
        ),
      ),
    ),
  );
}
