import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/admin_account.dart';
import '../../data/repositories/parking_repository.dart';
import '../../state/admin_controller.dart';
import '../alerts/alerts_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../occupancy/occupancy_screen.dart';
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

class AdminShellState extends State<AdminShell> with WidgetsBindingObserver {
  late final AdminController _controller;
  Timer? _liveTimer;
  Duration? _liveRefreshInterval;
  AdminTab _tab = AdminTab.dashboard;

  final _moreNavigatorKey = GlobalKey<NavigatorState>();

  AdminTab get tab => _tab;

  void selectTab(AdminTab tab) {
    if (tab == AdminTab.more && _tab == AdminTab.more) {
      _moreNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    setState(() => _tab = tab);
    if (tab == AdminTab.occupancy) {
      _loadOccupancy();
      _startOccupancyPolling();
    } else {
      _stopOccupancyPolling();
    }
  }

  void _startOccupancyPolling() {
    _stopOccupancyPolling();
    final interval = _liveRefreshInterval;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (interval == null ||
        lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return;
    }
    _liveTimer = Timer.periodic(interval, (_) {
      final monitoring = AppScope.of(context).monitoring;
      if (_tab == AdminTab.occupancy &&
          _controller.hasData &&
          !_controller.loading &&
          !monitoring.loading &&
          !monitoring.forbidden) {
        _controller.refresh();
        monitoring.refresh();
      }
    });
  }

  void _stopOccupancyPolling() {
    _liveTimer?.cancel();
    _liveTimer = null;
  }

  void _loadOccupancy() {
    final monitoring = AppScope.of(context).monitoring;
    if (_controller.hasData) _controller.refresh();
    if (monitoring.forbidden || monitoring.loading) return;
    if (monitoring.loaded) {
      monitoring.refresh();
    } else {
      monitoring.load();
    }
  }

  /// Sections of the More tab keep the bottom navigation, as in the mockups.
  static Route<void> moreSectionRoute(Widget page) =>
      MaterialPageRoute<void>(builder: (_) => Scaffold(body: page));

  void openMoreSection(Widget page) {
    setState(() => _tab = AdminTab.more);
    _stopOccupancyPolling();
    final navigator = _moreNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.popUntil((route) => route.isFirst);
    navigator.push(moreSectionRoute(page));
  }

  void _handleBack(bool didPop, Object? result) {
    if (didPop) return;
    final navigator = _moreNavigatorKey.currentState;
    if (_tab == AdminTab.more && navigator != null && navigator.canPop()) {
      navigator.pop();
    } else if (_tab != AdminTab.dashboard) {
      setState(() => _tab = AdminTab.dashboard);
      _stopOccupancyPolling();
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _tab == AdminTab.occupancy) {
      _loadOccupancy();
      _startOccupancyPolling();
    } else if (state != AppLifecycleState.resumed) {
      _stopOccupancyPolling();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AdminController(
      repository: widget.repository,
      account: widget.account,
    );
    _controller.load();
    _liveRefreshInterval = widget.liveRefreshInterval;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopOccupancyPolling();
    _controller.dispose();
    super.dispose();
  }

  Widget _tabBody(AdminTab tab) => switch (tab) {
    AdminTab.dashboard => const DashboardScreen(),
    AdminTab.occupancy => const OccupancyScreen(),
    AdminTab.alerts => const AlertsScreen(),
    AdminTab.more => Navigator(
      key: _moreNavigatorKey,
      onGenerateRoute: (_) =>
          MaterialPageRoute<void>(builder: (_) => const MoreScreen()),
    ),
  };

  @override
  Widget build(BuildContext context) {
    return AdminScope(
      controller: _controller,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: _handleBack,
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
            onDestinationSelected: (index) => selectTab(AdminTab.values[index]),
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
      ),
    );
  }
}
