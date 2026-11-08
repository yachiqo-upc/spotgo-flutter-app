import 'package:flutter/material.dart';

import '../../app/admin_navigation.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/guest_session.dart';
import '../shell/account_sheet.dart';
import 'guest_session_detail_screen.dart';
import 'new_guest_session_screen.dart';

enum GuestTab {
  active('Active'),
  completed('Completed'),
  issues('Issues');

  const GuestTab(this.label);

  final String label;
}

(String, BadgeTone) guestStatusBadge(GuestSession session, DateTime now) {
  if (session.isClosed) return ('Completed', BadgeTone.neutral);
  if (session.status == GuestSessionStatus.pendingReview) {
    return ('Pending review', BadgeTone.danger);
  }
  if (session.isOverstay(now)) return ('Overstay', BadgeTone.warning);
  if (session.exitRegistered) return ('Payment due', BadgeTone.info);
  return ('Active', BadgeTone.success);
}

/// Guest parking sessions list (mockup 21, US03).
class GuestSessionsScreen extends StatefulWidget {
  const GuestSessionsScreen({super.key});

  @override
  State<GuestSessionsScreen> createState() => _GuestSessionsScreenState();
}

class _GuestSessionsScreenState extends State<GuestSessionsScreen> {
  GuestTab _tab = GuestTab.active;

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final now = admin.now;
    final sessions = admin.guestSessions.where((s) {
      return switch (_tab) {
        GuestTab.active => !s.isClosed,
        GuestTab.completed => s.isClosed,
        GuestTab.issues => s.hasIssue(now),
      };
    }).toList();

    return RefreshIndicator(
      onRefresh: admin.refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: PageContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                title: 'Guest parking sessions',
                subtitle: 'Manual sessions for external vehicles in your zone',
                onProfileTap: () => showAccountSheet(context),
                onBack: Navigator.of(context).canPop()
                    ? () => Navigator.of(context).maybePop()
                    : null,
              ),
              _SegmentedTabs(
                selected: _tab,
                onSelected: (tab) => setState(() => _tab = tab),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                key: const Key('guest-new'),
                onPressed: () =>
                    pushAdminPage<void>(context, const NewGuestSessionScreen()),
                child: const Text('New guest session'),
              ),
              const SizedBox(height: 14),
              if (sessions.isEmpty)
                Card(
                  child: EmptyView(
                    icon: Icons.directions_car_outlined,
                    title: switch (_tab) {
                      GuestTab.active => 'No active guest sessions',
                      GuestTab.completed => 'No completed sessions yet',
                      GuestTab.issues => 'No sessions with issues',
                    },
                  ),
                )
              else
                for (final session in sessions) ...[
                  _GuestSessionCard(session: session, now: now),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 4),
              const NoticeCard(
                message:
                    'External vehicles · No Driver account, reservation or '
                    'digital payment. Managed by an Administrator.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.selected, required this.onSelected});

  final GuestTab selected;
  final ValueChanged<GuestTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final tab in GuestTab.values)
            Expanded(
              child: Material(
                color: tab == selected
                    ? AppColors.primaryMuted
                    : Colors.transparent,
                child: InkWell(
                  key: Key('guest-tab-${tab.name}'),
                  onTap: () => onSelected(tab),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tab == selected) ...[
                          const Icon(
                            Icons.check,
                            size: 16,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          tab.label,
                          style: TextStyle(
                            color: tab == selected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GuestSessionCard extends StatelessWidget {
  const _GuestSessionCard({required this.session, required this.now});

  final GuestSession session;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.of(context);
    final (label, tone) = guestStatusBadge(session, now);
    final timing = session.isClosed && session.exitAt != null
        ? 'Started ${Formatters.time(session.entryAt)} · '
              'Closed ${Formatters.time(session.exitAt!)}'
        : 'Started ${Formatters.time(session.entryAt)} · '
              '${Formatters.duration(session.elapsed(now))}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('guest-card-${session.id}'),
        onTap: () => pushAdminPage<void>(
          context,
          GuestSessionDetailScreen(sessionId: session.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.plate,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  StatusBadge(label: label, tone: tone),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${admin.facilityName} · Spot ${session.spotCode}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(timing, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
