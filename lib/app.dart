import 'package:flutter/material.dart';
import 'navigation/app_nav.dart';
import 'screens/account_screen.dart';
import 'screens/attendance_dtr_screen.dart';
import 'screens/credentials_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/leave_monitoring_screen.dart';
import 'screens/notifications_screen.dart';
import 'theme/app_theme.dart';

class NuhrisEmployeeApp extends StatefulWidget {
  const NuhrisEmployeeApp({
    super.key,
    required this.onSignOut,
  });

  final VoidCallback onSignOut;

  @override
  State<NuhrisEmployeeApp> createState() => _NuhrisEmployeeAppState();
}

class _NuhrisEmployeeAppState extends State<NuhrisEmployeeApp> {
  AppNavItem current = AppNavItem.dashboard;

  void _navigate(AppNavItem item) {
    setState(() => current = item);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: switch (current) {
        AppNavItem.dashboard => DashboardScreen(onNavigate: _navigate, onSignOut: widget.onSignOut),
        AppNavItem.credentials => CredentialsScreen(onNavigate: _navigate, onSignOut: widget.onSignOut),
        AppNavItem.attendanceDtr => AttendanceDtrScreen(onNavigate: _navigate, onSignOut: widget.onSignOut),
        AppNavItem.leaveMonitoring => LeaveMonitoringScreen(onNavigate: _navigate, onSignOut: widget.onSignOut),
        AppNavItem.notifications => NotificationsScreen(onNavigate: _navigate, onSignOut: widget.onSignOut),
        AppNavItem.account => AccountScreen(onNavigate: _navigate, onSignOut: widget.onSignOut),
      },
    );
  }
}
