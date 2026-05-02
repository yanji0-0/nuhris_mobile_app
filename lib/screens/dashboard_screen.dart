import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/app_nav.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/dashboard_calendar.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({
    super.key,
    required this.onNavigate,
    required this.onSignOut,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);

    if (state.isLoading) {
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
          backgroundColor: const Color(0xFF0A1B66),
          foregroundColor: Colors.white,
          surfaceTintColor: const Color(0xFF0A1B66),
          elevation: 0,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
          title: const Text('Dashboard'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state.hasError) {
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
          backgroundColor: const Color(0xFF0A1B66),
          foregroundColor: Colors.white,
          surfaceTintColor: const Color(0xFF0A1B66),
          elevation: 0,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
          title: const Text('Dashboard'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Failed to load dashboard: ${state.error}'),
          ),
        ),
      );
    }

    final payload = state.value ?? {};
    final dashboard =
        (payload['dashboard'] as Map?)?.cast<String, dynamic>() ?? {};
    final notifications = ((payload['notifications'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

    final employee =
        (dashboard['employee'] as Map?)?.cast<String, dynamic>() ?? {};
    final leaveSummary =
        (dashboard['leave_summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final credentialsSummary =
        (dashboard['credentials_summary'] as Map?)?.cast<String, dynamic>() ??
        {};
    final notificationsSummary =
        (dashboard['notifications_summary'] as Map?)?.cast<String, dynamic>() ??
        {};

    final activeCredentialsCount =
        (credentialsSummary['active_count'] ?? 0) as num;
    final expiringSoonCount =
        (credentialsSummary['expiring_soon_count'] ?? 0) as num;
    final nonCompliantCount =
        (credentialsSummary['non_compliant_count'] ?? 0) as num;
    final compliantCount =
        (credentialsSummary['compliant_count'] ?? activeCredentialsCount)
            as num;
    final totalCredentialCount =
        (credentialsSummary['total_count'] ?? 0) as num;
    final totalLeaveDays = ((leaveSummary['total_days_remaining'] ?? 0) as num)
        .toDouble();
    final totalNotifications =
        (notificationsSummary['total_count'] ?? notifications.length) as num;

    final firstName = (employee['first_name'] ?? '').toString().trim();
    final lastName = (employee['last_name'] ?? '').toString().trim();
    final combinedName = '$firstName $lastName'.trim();
    final fallbackName = (employee['name'] ?? '').toString().trim();
    final welcomeName = combinedName.isNotEmpty
        ? combinedName
        : (fallbackName.isNotEmpty ? fallbackName : 'Employee');

    final complianceValue =
        '${compliantCount.toInt()}/${totalCredentialCount.toInt()}';
    final metrics = [
      _MetricData(
        title: 'Active Credentials',
        value: activeCredentialsCount.toInt().toString(),
        subtitle: '${expiringSoonCount.toInt()} pending review',
      ),
      _MetricData(
        title: 'Compliance',
        value: complianceValue,
        subtitle: 'Up to date',
      ),
      _MetricData(
        title: 'Leave Balance',
        value: totalLeaveDays % 1 == 0
            ? totalLeaveDays.toInt().toString()
            : totalLeaveDays.toStringAsFixed(1),
        subtitle: 'Total days remaining',
      ),
      _MetricData(
        title: 'Notifications',
        value: totalNotifications.toInt().toString(),
        subtitle: 'Recent alerts',
      ),
    ];

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
        backgroundColor: const Color(0xFF0A1B66),
        foregroundColor: Colors.white,
        surfaceTintColor: const Color(0xFF0A1B66),
        elevation: 0,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('Dashboard'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1100;
          final horizontalPad = isWide ? 22.0 : 14.0;

          final metricsGrid = GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: metrics.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 4 : 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: isWide
                  ? 2.8
                  : (constraints.maxWidth < 420 ? 1.45 : 1.65),
            ),
            itemBuilder: (context, index) => _MetricCard(data: metrics[index]),
          );

          final complianceTitleSize = constraints.maxWidth >= 900 ? 36.0 : 28.0;

          final compliancePanel = Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compliance Status',
                    style: TextStyle(
                      color: const Color(0xFF11284F),
                      fontSize: complianceTitleSize,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _StatusRow(
                    label: 'Compliant',
                    color: AppColors.green,
                    value: compliantCount.toInt().toString(),
                  ),
                  const SizedBox(height: 10),
                  _StatusRow(
                    label: 'Expiring Soon',
                    color: AppColors.orange,
                    value: expiringSoonCount.toInt().toString(),
                  ),
                  const SizedBox(height: 10),
                  _StatusRow(
                    label: 'Non-Compliant',
                    color: AppColors.red,
                    value: nonCompliantCount.toInt().toString(),
                  ),
                ],
              ),
            ),
          );

          final recentAlertsPanel = Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Recent Alerts',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => onNavigate(AppNavItem.notifications),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (notifications.isEmpty)
                    const Text(
                      'No recent alerts available.',
                      style: TextStyle(color: AppColors.mutedText),
                    )
                  else
                    ...notifications.take(3).map((n) {
                      final announcement =
                          (n['announcement'] as Map?)
                              ?.cast<String, dynamic>() ??
                          {};
                      final title = (announcement['title'] ?? 'Notification')
                          .toString();
                      final timestamp =
                          (announcement['published_at'] ??
                                  n['created_at'] ??
                                  '')
                              .toString();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F9FD),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDCE2ED)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatTimestamp(timestamp),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          );

          final calendarPanel = Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'System Calendar',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  DashboardCalendar(),
                  const SizedBox(height: 14),
                  const Text(
                    'UPCOMING EVENTS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (notifications.isEmpty)
                    const Text(
                      'No upcoming events yet.',
                      style: TextStyle(color: AppColors.mutedText),
                    )
                  else
                    ...notifications.take(2).map((n) {
                      final announcement =
                          (n['announcement'] as Map?)
                              ?.cast<String, dynamic>() ??
                          {};
                      final title = (announcement['title'] ?? 'Notification')
                          .toString();
                      final subtitle =
                          (announcement['published_at'] ??
                                  n['created_at'] ??
                                  '')
                              .toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _EventRow(
                          color: AppColors.primaryBlue,
                          title: title,
                          subtitle: _formatTimestamp(subtitle),
                        ),
                      );
                    }),
                ],
              ),
            ),
          );

          if (!isWide) {
            return ListView(
              padding: const EdgeInsets.only(bottom: 18),
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                  child: Text(
                    'Welcome back, $welcomeName!',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                  child: const Text(
                    'Here is an overview of your HR information.',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                  child: metricsGrid,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                  child: compliancePanel,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                  child: recentAlertsPanel,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                  child: calendarPanel,
                ),
              ],
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(horizontalPad, 10, horizontalPad, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $welcomeName!',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Here is an overview of your HR information.',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 22),
                ),
                const SizedBox(height: 14),
                metricsGrid,
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          compliancePanel,
                          const SizedBox(height: 14),
                          recentAlertsPanel,
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: calendarPanel),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(String value) {
    if (value.isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('MMM d, hh:mm a').format(parsed.toLocal());
  }
}

class _MetricData {
  const _MetricData({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 190 || constraints.maxHeight < 130;

        return Card(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14,
              vertical: compact ? 10 : 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 12 : 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedText,
                  ),
                ),
                SizedBox(height: compact ? 2 : 4),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        data.value,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: compact ? 34 : 44,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: compact ? 2 : 4),
                Text(
                  data.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 12 : 16,
                    color: AppColors.mutedText,
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

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.color,
    required this.value,
  });
  final String label;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1D9E6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF10264A),
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 36,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.color,
    required this.title,
    required this.subtitle,
  });
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
