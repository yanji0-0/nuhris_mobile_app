import 'package:flutter/material.dart';
import '../navigation/app_nav.dart';
import '../theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onSignOut,
  });

  final AppNavItem selected;
  final ValueChanged<AppNavItem> onSelect;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.navy,
      child: SafeArea(
        child: Column(
          children: [
            _Header(),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  _DrawerItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    selected: selected == AppNavItem.dashboard,
                    onTap: () => onSelect(AppNavItem.dashboard),
                  ),
                  _DrawerItem(
                    icon: Icons.badge_outlined,
                    label: 'Credentials',
                    selected: selected == AppNavItem.credentials,
                    onTap: () => onSelect(AppNavItem.credentials),
                  ),
                  _DrawerItem(
                    icon: Icons.access_time,
                    label: 'Attendance & DTR',
                    selected: selected == AppNavItem.attendanceDtr,
                    onTap: () => onSelect(AppNavItem.attendanceDtr),
                  ),
                  _DrawerItem(
                    icon: Icons.calendar_month_outlined,
                    label: 'Leave Monitoring',
                    selected: selected == AppNavItem.leaveMonitoring,
                    onTap: () => onSelect(AppNavItem.leaveMonitoring),
                  ),
                  _DrawerItem(
                    icon: Icons.notifications_none,
                    label: 'Notifications',
                    selected: selected == AppNavItem.notifications,
                    onTap: () => onSelect(AppNavItem.notifications),
                  ),
                  _DrawerItem(
                    icon: Icons.person_outline,
                    label: 'Account',
                    selected: selected == AppNavItem.account,
                    onTap: () => onSelect(AppNavItem.account),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onSignOut,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  child: Row(
                    children: const [
                      Icon(Icons.logout, color: Colors.white70),
                      SizedBox(width: 12),
                      Text(
                        'Sign Out',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simple logo placeholder (replace with Image.asset later)
          Row(
            children: const [
              Icon(Icons.apartment, color: AppColors.nuhrisYellow, size: 28),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NUHRIS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Text(
                    'Employee Portal',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  )
                ],
              )
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.nuhrisYellow,
                child: Icon(Icons.person, color: AppColors.navy, size: 18),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Martinez, Ian Isaac',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'martinezian@gmail.com',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.nuhrisYellow : Colors.transparent;
    final fg = selected ? AppColors.navy : Colors.white70;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            child: Row(
              children: [
                Icon(icon, color: fg),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}