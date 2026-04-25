import 'package:flutter/material.dart';
import 'navigation/app_nav.dart';
import 'screens/account_screen.dart';
import 'screens/attendance_dtr_screen.dart';
import 'screens/credentials_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/leave_monitoring_screen.dart';
import 'screens/notifications_screen.dart';
import 'services/api_client.dart';
import 'theme/app_theme.dart';

class NuhrisEmployeeApp extends StatefulWidget {
  const NuhrisEmployeeApp({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  State<NuhrisEmployeeApp> createState() => _NuhrisEmployeeAppState();
}

class _NuhrisEmployeeAppState extends State<NuhrisEmployeeApp> {
  AppNavItem current = AppNavItem.dashboard;
  bool _checkingAccess = true;

  @override
  void initState() {
    super.initState();
    _guardAccess();
  }

  Future<void> _guardAccess() async {
    final allowed = await ApiClient.instance.hasEmployeeAccess();
    if (!mounted) {
      return;
    }
    if (!allowed) {
      widget.onSignOut();
      return;
    }
    setState(() => _checkingAccess = false);
  }

  void _navigate(AppNavItem item) {
    setState(() => current = item);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: switch (current) {
        AppNavItem.dashboard => DashboardScreen(
          onNavigate: _navigate,
          onSignOut: widget.onSignOut,
        ),
        AppNavItem.credentials => CredentialsScreen(
          onNavigate: _navigate,
          onSignOut: widget.onSignOut,
        ),
        AppNavItem.attendanceDtr => AttendanceDtrScreen(
          onNavigate: _navigate,
          onSignOut: widget.onSignOut,
        ),
        AppNavItem.leaveMonitoring => LeaveMonitoringScreen(
          onNavigate: _navigate,
          onSignOut: widget.onSignOut,
        ),
        AppNavItem.notifications => NotificationsScreen(
          onNavigate: _navigate,
          onSignOut: widget.onSignOut,
        ),
        AppNavItem.account => AccountScreen(
          onNavigate: _navigate,
          onSignOut: widget.onSignOut,
        ),
      },
    );
  }
}
