import 'package:flutter/material.dart';
import '../navigation/app_nav.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/dashboard_calendar.dart';
import '../widgets/section_title.dart';
import '../widgets/summary_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.onNavigate,
    required this.onSignOut,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        selected: AppNavItem.dashboard,
        onSelect: (item) {
          Navigator.pop(context);
          onNavigate(item);
        },
        onSignOut: onSignOut,
      ),
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 18),
        children: [
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text('Welcome back, Ian!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'Here is an overview of your HR information.',
              style: TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
          ),
          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: const [
                SummaryCard(
                  title: 'Active Credentials',
                  value: '0',
                  subtitle: '0 pending review',
                  icon: Icons.description_outlined,
                  iconColor: AppColors.primaryBlue,
                ),
                SizedBox(height: 10),
                SummaryCard(
                  title: 'Compliances',
                  value: '0/0',
                  subtitle: 'Up to date',
                  icon: Icons.schedule,
                  iconColor: AppColors.green,
                ),
                SizedBox(height: 10),
                SummaryCard(
                  title: 'Leave Balance',
                  value: '0',
                  subtitle: 'Total days remaining',
                  icon: Icons.calendar_month_outlined,
                  iconColor: AppColors.orange,
                ),
                SizedBox(height: 10),
                SummaryCard(
                  title: 'Notifications',
                  value: '3',
                  subtitle: 'Recent alerts',
                  icon: Icons.notifications_none,
                  iconColor: AppColors.purple,
                ),
              ],
            ),
          ),

          const SectionTitle(title: 'Compliance Status'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: const [
                    _StatusRow(label: 'Compliant', color: AppColors.green, value: '0', icon: Icons.check_circle_outline),
                    SizedBox(height: 10),
                    _StatusRow(label: 'Expiring Soon', color: AppColors.amber, value: '0', icon: Icons.error_outline),
                    SizedBox(height: 10),
                    _StatusRow(label: 'Non-Compliant', color: AppColors.red, value: '0', icon: Icons.cancel_outlined),
                  ],
                ),
              ),
            ),
          ),

          SectionTitle(
            title: 'Recent Alerts',
            trailing: TextButton(
              onPressed: () {},
              child: const Text('View All'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: const [
                _AlertTile(
                  iconBg: Color(0xFFEFF6FF),
                  icon: Icons.badge_outlined,
                  iconColor: AppColors.primaryBlue,
                  title: 'PRC License Renewal Reminder',
                  subtitle: 'Feb 15, 2026 9:25 PM',
                ),
                SizedBox(height: 10),
                _AlertTile(
                  iconBg: Color(0xFFF0FDF4),
                  icon: Icons.schedule,
                  iconColor: AppColors.green,
                  title: 'DTR Released: January 16–31',
                  subtitle: 'Feb 12, 2026 9:58 PM',
                ),
                SizedBox(height: 10),
                _AlertTile(
                  iconBg: Color(0xFFFFFBEB),
                  icon: Icons.campaign_outlined,
                  iconColor: AppColors.amber,
                  title: 'New Leave Policy Update',
                  subtitle: 'Feb 1, 2026 5:21 PM',
                ),
              ],
            ),
          ),

          const SectionTitle(title: 'System Calendar'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DashboardCalendar(),
                    const SizedBox(height: 12),
                    const Text('UPCOMING EVENTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.mutedText)),
                    const SizedBox(height: 10),
                    const _EventRow(color: AppColors.orange, title: 'EDSA People Power Anniversary', subtitle: 'Feb 25, 2026'),
                    const SizedBox(height: 8),
                    const _EventRow(color: AppColors.purple, title: 'CHED Compliance Deadline', subtitle: 'Feb 22, 2026'),
                    const SizedBox(height: 8),
                    const _EventRow(color: AppColors.primaryBlue, title: 'Midterm Exams', subtitle: 'Mar 3, 2026'),
                    const SizedBox(height: 8),
                    const _EventRow(color: AppColors.amber, title: 'Faculty Development Seminar', subtitle: 'Mar 15, 2026'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.color,
    required this.value,
    required this.icon,
  });

  final String label;
  final Color color;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.mutedText, fontSize: 11)),
        onTap: () {},
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.color, required this.title, required this.subtitle});

  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              Text(subtitle, style: const TextStyle(color: AppColors.mutedText, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}