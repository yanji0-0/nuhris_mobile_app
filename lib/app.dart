import 'package:flutter/material.dart';
import 'navigation/app_nav.dart';
import 'screens/credentials_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/leave_monitoring_screen.dart';
import 'theme/app_theme.dart';

class NuhrisEmployeeApp extends StatefulWidget {
  const NuhrisEmployeeApp({super.key});

  @override
  State<NuhrisEmployeeApp> createState() => _NuhrisEmployeeAppState();
}

class _NuhrisEmployeeAppState extends State<NuhrisEmployeeApp> {
  AppNavItem current = AppNavItem.dashboard;

  void _navigate(AppNavItem item) {
    // Still UI-first; only some pages implemented
    if (item == AppNavItem.attendanceDtr ||
        item == AppNavItem.notifications ||
        item == AppNavItem.account) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${navTitle(item)} not implemented yet (UI only)')),
      );
      return;
    }

    setState(() => current = item);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: switch (current) {
        AppNavItem.dashboard => DashboardScreen(onNavigate: _navigate),
        AppNavItem.credentials => CredentialsScreen(onNavigate: _navigate),
        AppNavItem.leaveMonitoring => LeaveMonitoringScreen(onNavigate: _navigate),
        _ => DashboardScreen(onNavigate: _navigate),
      },
    );
  }
}