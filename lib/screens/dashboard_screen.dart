import 'package:flutter/material.dart';
import '../navigation/app_nav.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/dashboard_calendar.dart';
import '../widgets/section_title.dart';
import '../widgets/summary_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.onNavigate,
    required this.onSignOut,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<Map<String, dynamic>> _loadData() async {
    final dashboard = await ApiClient.instance.getDashboard();
    final notifications = await ApiClient.instance.getNotifications();
    final supabaseProbe = await ApiClient.instance.getSupabaseHealth();
    final supabaseSummary = await ApiClient.instance.getSupabaseSummary();
    return {
      'dashboard': dashboard,
      'notifications': notifications,
      'supabase_probe': supabaseProbe,
      'supabase_summary': supabaseSummary,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        selected: AppNavItem.dashboard,
        onSelect: (item) {
          Navigator.pop(context);
          widget.onNavigate(item);
        },
        onSignOut: widget.onSignOut,
      ),
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load dashboard: ${snapshot.error}'),
              ),
            );
          }

          final payload = snapshot.data ?? {};
          final dashboard = (payload['dashboard'] as Map?)?.cast<String, dynamic>() ?? {};
          final notifications = ((payload['notifications'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList();
          final supabaseProbe = (payload['supabase_probe'] as Map?)?.cast<String, dynamic>() ?? {};
          final supabaseSummary = (payload['supabase_summary'] as Map?)?.cast<String, dynamic>() ?? {};

          final employee = (dashboard['employee'] as Map?)?.cast<String, dynamic>() ?? {};
          final attendanceSummary = (dashboard['attendance_summary'] as Map?)?.cast<String, dynamic>() ?? {};
          final leaveSummary = (dashboard['leave_summary'] as Map?)?.cast<String, dynamic>() ?? {};
          final supabaseConnected = supabaseProbe['connected'] == true;
          final supabaseSubtitle = supabaseConnected
              ? 'Table users, rows fetched: ${(supabaseProbe['row_count'] ?? 0).toString()}'
              : (supabaseProbe['message'] ?? 'Unable to read users table').toString();
          final supabaseCounts = (supabaseSummary['counts'] as Map?)?.cast<String, dynamic>() ?? {};
          final activeCredentialsCount = (supabaseCounts['employee_credentials'] ?? 0).toString();

          final welcomeName = (employee['first_name'] ?? '').toString().isEmpty
              ? 'Employee'
              : (employee['first_name']).toString();

          return ListView(
            padding: const EdgeInsets.only(bottom: 18),
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text('Welcome back, $welcomeName!', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
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
                  children: [
                    SummaryCard(
                      title: 'Active Credentials',
                      value: activeCredentialsCount,
                      subtitle: 'From Supabase employee_credentials',
                      icon: Icons.description_outlined,
                      iconColor: AppColors.primaryBlue,
                    ),
                    const SizedBox(height: 10),
                    SummaryCard(
                      title: 'Attendance (Present)',
                      value: (attendanceSummary['present'] ?? 0).toString(),
                      subtitle: 'Current records',
                      icon: Icons.schedule,
                      iconColor: AppColors.green,
                    ),
                    const SizedBox(height: 10),
                    SummaryCard(
                      title: 'Leave Balance Sets',
                      value: (leaveSummary['balance_count'] ?? 0).toString(),
                      subtitle: 'Types with balances',
                      icon: Icons.calendar_month_outlined,
                      iconColor: AppColors.orange,
                    ),
                    const SizedBox(height: 10),
                    SummaryCard(
                      title: 'Notifications',
                      value: notifications.length.toString(),
                      subtitle: 'Recent alerts',
                      icon: Icons.notifications_none,
                      iconColor: AppColors.purple,
                    ),
                    const SizedBox(height: 10),
                    SummaryCard(
                      title: 'Supabase',
                      value: supabaseConnected ? 'OK' : 'ERR',
                      subtitle: supabaseSubtitle,
                      icon: supabaseConnected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                      iconColor: supabaseConnected ? AppColors.green : AppColors.red,
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
                      children: [
                        _StatusRow(label: 'Present', color: AppColors.green, value: (attendanceSummary['present'] ?? 0).toString(), icon: Icons.check_circle_outline),
                        const SizedBox(height: 10),
                        _StatusRow(label: 'Absent', color: AppColors.amber, value: (attendanceSummary['absent'] ?? 0).toString(), icon: Icons.error_outline),
                        const SizedBox(height: 10),
                        _StatusRow(label: 'On Leave', color: AppColors.red, value: (attendanceSummary['on_leave'] ?? 0).toString(), icon: Icons.cancel_outlined),
                      ],
                    ),
                  ),
                ),
              ),
              SectionTitle(
                title: 'Recent Alerts',
                trailing: TextButton(onPressed: () => widget.onNavigate(AppNavItem.notifications), child: const Text('View All')),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: notifications.take(3).map((n) {
                    final announcement = (n['announcement'] as Map?)?.cast<String, dynamic>() ?? {};
                    final title = (announcement['title'] ?? 'Notification').toString();
                    final subtitle = (announcement['published_at'] ?? n['created_at'] ?? '').toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AlertTile(
                        iconBg: const Color(0xFFEFF6FF),
                        icon: Icons.campaign_outlined,
                        iconColor: AppColors.primaryBlue,
                        title: title,
                        subtitle: subtitle,
                      ),
                    );
                  }).toList(),
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
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.color, required this.value, required this.icon});
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
  const _AlertTile({required this.iconBg, required this.icon, required this.iconColor, required this.title, required this.subtitle});
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
