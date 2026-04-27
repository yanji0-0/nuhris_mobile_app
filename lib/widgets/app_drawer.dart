import 'package:flutter/material.dart';
import '../navigation/app_nav.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

class AppDrawer extends StatefulWidget {
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
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  late final Future<Map<String, dynamic>> _accountFuture;

  @override
  void initState() {
    super.initState();
    _accountFuture = ApiClient.instance.getAccount();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _accountFuture,
      builder: (context, snapshot) {
        final account = snapshot.data ?? const <String, dynamic>{};
        final user =
            (account['user'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        final employee =
            (account['employee'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};

        final firstName = (employee['first_name'] ?? '').toString().trim();
        final lastName = (employee['last_name'] ?? '').toString().trim();
        final fullName = [lastName, firstName]
            .where((part) => part.isNotEmpty)
            .join(', ');
        final displayName = fullName.isNotEmpty
            ? fullName
            : (user['name'] ?? 'Employee').toString();

        final email = (employee['email'] ?? user['email'] ?? '').toString();

        return Drawer(
          backgroundColor: const Color(0xFF0A1B66),
          child: SafeArea(
            child: Column(
              children: [
                _Header(displayName: displayName, email: email),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    children: [
                      _DrawerItem(
                        icon: Icons.dashboard_outlined,
                        label: 'Dashboard',
                        selected: widget.selected == AppNavItem.dashboard,
                        onTap: () => widget.onSelect(AppNavItem.dashboard),
                      ),
                      _DrawerItem(
                        icon: Icons.badge_outlined,
                        label: 'Credentials',
                        selected: widget.selected == AppNavItem.credentials,
                        onTap: () => widget.onSelect(AppNavItem.credentials),
                      ),
                      _DrawerItem(
                        icon: Icons.access_time,
                        label: 'Attendance & DTR',
                        selected: widget.selected == AppNavItem.attendanceDtr,
                        onTap: () => widget.onSelect(AppNavItem.attendanceDtr),
                      ),
                      _DrawerItem(
                        icon: Icons.calendar_month_outlined,
                        label: 'Leave Monitoring',
                        selected: widget.selected == AppNavItem.leaveMonitoring,
                        onTap: () => widget.onSelect(AppNavItem.leaveMonitoring),
                      ),
                      _DrawerItem(
                        icon: Icons.notifications_none,
                        label: 'Notifications',
                        selected: widget.selected == AppNavItem.notifications,
                        onTap: () => widget.onSelect(AppNavItem.notifications),
                      ),
                      _DrawerItem(
                        icon: Icons.person_outline,
                        label: 'Account',
                        selected: widget.selected == AppNavItem.account,
                        onTap: () => widget.onSelect(AppNavItem.account),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0x33FFFFFF)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                  child: Row(
                    children: [
                      Text(
                        'NATIONAL UNIVERSITY',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'HRIS · v1.0',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: widget.onSignOut,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            children: [
                              Icon(Icons.logout, color: Colors.white70, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Sign Out',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.displayName, required this.email});

  final String displayName;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF162B73), Color(0xFF12266C)],
        ),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.nuhrisYellow,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'N',
                  style: TextStyle(
                    color: Color(0xFF0A1B66),
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NU Lipa',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 34,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    'HRIS SELF-SERVICE',
                    style: TextStyle(
                      color: Color(0xFFBDD3FF),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  )
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.nuhrisYellow,
                child: Icon(Icons.person, color: AppColors.navy, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      email.isNotEmpty ? email : 'No email on record',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              )
            ],
            ),
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
    final fg = selected ? const Color(0xFF041D6D) : const Color(0xFFDAE4FF);
    final iconFg = selected ? const Color(0xFF041D6D) : const Color(0xFFC6D7FF);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: selected
                ? null
                : Border.all(color: Colors.transparent, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            child: Row(
              children: [
                Icon(icon, color: iconFg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.circle,
                    size: 9,
                    color: Color(0xFF041D6D),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
