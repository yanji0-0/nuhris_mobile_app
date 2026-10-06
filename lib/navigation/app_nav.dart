enum AppNavItem {
  dashboard,
  academicCalendar,
  attendanceDtr,
  wfhMonitoring,
  leaveMonitoring,
  notifications,
  account,
}

String navTitle(AppNavItem item) {
  switch (item) {
    case AppNavItem.dashboard:
      return 'Dashboard';
    case AppNavItem.academicCalendar:
      return 'Academic Calendar';
    case AppNavItem.attendanceDtr:
      return 'Attendance & DTR';
    case AppNavItem.wfhMonitoring:
      return 'WFH Monitoring';
    case AppNavItem.leaveMonitoring:
      return 'Leave Monitoring';
    case AppNavItem.notifications:
      return 'Notifications';
    case AppNavItem.account:
      return 'Profile';
  }
}
