enum AppNavItem {
  dashboard,
  credentials,
  attendanceDtr,
  leaveMonitoring,
  notifications,
  account,
}

String navTitle(AppNavItem item) {
  switch (item) {
    case AppNavItem.dashboard:
      return 'Dashboard';
    case AppNavItem.credentials:
      return 'Credentials';
    case AppNavItem.attendanceDtr:
      return 'Attendance & DTR';
    case AppNavItem.leaveMonitoring:
      return 'Leave Monitoring';
    case AppNavItem.notifications:
      return 'Notifications';
    case AppNavItem.account:
      return 'Account';
  }
}