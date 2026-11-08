import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/admin_account.dart';
import '../../data/repositories/parking_repository.dart';
import '../../state/admin_controller.dart';
import '../dashboard/dashboard_screen.dart';
import 'account_sheet.dart';
import 'more_screen.dart';

enum AdminTab { dashboard, occupancy, alerts, more }

/// Root of the authenticated area: bottom navigation from the mockups and
/// lifecycle of the [AdminController].
class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    required this.account,
    required this.repository,
    this.liveRefreshInterval,
  });

  final AdminAccount account;
  final ParkingRepository repository;
  final Duration? liveRefreshInterval;

  static AdminShellState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<AdminShellState>();

  @override
  State<AdminShell> createState() => AdminShellState();
}

class AdminShellState extends State<AdminShell> {
  late final AdminController _controller;
  Timer? _liveTimer;
  AdminTab _tab = AdminTab.dashboard;

  AdminTab get tab => _tab;

  void selectTab(AdminTab tab) => setState(() => _tab = tab);

  @override
  void initState() {
    super.initState();
    _controller = AdminController(
      repository: widget.repository,
      account: widget.account,
    );
    _controller.load();
    final interval = widget.liveRefreshInterval;
    if (interval != null) {
      _liveTimer = Timer.periodic(interval, (_) {
        if (_controller.hasData && !_controller.loading) _controller.refresh();
      });
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _tabBody(AdminTab tab) => switch (tab) {
    AdminTab.dashboard => const DashboardScreen(),
    AdminTab.occupancy => const _PlannedTab(title: 'Live occupancy'),
    AdminTab.alerts => const _PlannedTab(title: 'Operational alerts'),
    AdminTab.more => const MoreScreen(),
  };

  @override
  Widget build(BuildContext context) {
    return AdminScope(
      controller: _controller,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              if (!_controller.hasData) {
                if (_controller.error != null) {
                  return ErrorView(
                    message: _controller.error!,
                    onRetry: _controller.load,
                  );
                }
                return const LoadingView(message: 'Loading parking data...');
              }
              return IndexedStack(
                index: _tab.index,
                children: [for (final tab in AdminTab.values) _tabBody(tab)],
              );
            },
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab.index,
          onDestinationSelected: (index) =>
              selectTab(AdminTab.values[index]),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.directions_car_outlined),
              selectedIcon: Icon(Icons.directions_car),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.location_on_outlined),
              selectedIcon: Icon(Icons.location_on),
              label: 'Occupancy',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_none),
              selectedIcon: Icon(Icons.notifications),
              label: 'Alerts',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}

class _PlannedTab extends StatelessWidget {
  const _PlannedTab({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: PageContainer(
        child: ScreenHeader(
          title: title,
          subtitle: 'Section under construction',
          onProfileTap: () => showAccountSheet(context),
        ),
      ),
    );
  }
}
