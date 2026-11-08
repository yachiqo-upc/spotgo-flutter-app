import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/state_views.dart';

/// Administrative audit trail: user, action, date/time, old and new data
/// (US07, scenario 3).
class AuditHistoryScreen extends StatelessWidget {
  const AuditHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final entries = admin.audit;

    return Scaffold(
      appBar: AppBar(title: const Text('Audit history')),
      body: entries.isEmpty
          ? const Center(
              child: EmptyView(
                icon: Icons.history,
                title: 'No changes recorded yet',
                message:
                    'Zone, guest session and alert changes made in this '
                    'session will appear here.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return PageContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.action,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${entry.actor} · '
                            '${Formatters.dayAndTime(entry.at, admin.now)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Before: ${entry.before}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'After: ${entry.after}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
