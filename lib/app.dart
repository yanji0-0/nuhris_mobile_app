import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'navigation/app_nav.dart';
import 'providers/app_refresh_provider.dart';

import 'screens/account_screen.dart';
import 'screens/attendance_dtr_screen.dart';
import 'screens/credentials_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/leave_monitoring_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/wfh_monitoring_screen.dart';

import 'theme/app_theme.dart';

class NuhrisEmployeeApp
    extends ConsumerStatefulWidget {
  const NuhrisEmployeeApp({
    super.key,
    required this.onSignOut,
  });

  final VoidCallback onSignOut;

  @override
  ConsumerState<NuhrisEmployeeApp> createState() =>
      _NuhrisEmployeeAppState();
}

class _NuhrisEmployeeAppState
    extends ConsumerState<NuhrisEmployeeApp>
    with WidgetsBindingObserver {
  AppNavItem current =
      AppNavItem.dashboard;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _startRefreshTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _refreshTimer?.cancel();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state ==
        AppLifecycleState.resumed) {
      _triggerRefresh();
      _startRefreshTimer();
    } else if (state ==
            AppLifecycleState.paused ||
        state ==
            AppLifecycleState.inactive ||
        state ==
            AppLifecycleState.hidden) {
      _refreshTimer?.cancel();
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) {
        _triggerRefresh();
      },
    );
  }

  void _triggerRefresh() {
    if (!mounted) {
      return;
    }

    ref
        .read(appRefreshProvider.notifier)
        .trigger();
  }

  void _navigate(AppNavItem item) {
    setState(() {
      current = item;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget screen;

    switch (current) {
      case AppNavItem.dashboard:
        screen = DashboardScreen(
          onNavigate: _navigate,
          onSignOut: widget.onSignOut,
        );
        break;

      case AppNavItem.credentials:
        screen = CredentialsScreen(
          onNavigate: _navigate,
          onSignOut: widget.onSignOut,
        );
        break;

      case AppNavItem.attendanceDtr:
        screen = AttendanceDtrScreen(
          onNavigate: _navigate,
          onSignOut: widget.onSignOut,
        );
        break;

      case AppNavItem.wfhMonitoring:
        screen = WFHMonitoringScreen(
          onNavigate: _navigate,
          onSignOut: widget.onSignOut,
        );
        break;

      case AppNavItem.leaveMonitoring:
        screen = LeaveMonitoringScreen(
          onNavigate: _navigate,
          onSignOut: widget.onSignOut,
        );
        break;

      case AppNavItem.notifications:
        screen = NotificationsScreen(
          onNavigate: _navigate,
          onSignOut: widget.onSignOut,
        );
        break;

      case AppNavItem.account:
        screen = AccountScreen(
          onNavigate: _navigate,
          onSignOut: widget.onSignOut,
        );
        break;
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: screen,
    );
  }
}