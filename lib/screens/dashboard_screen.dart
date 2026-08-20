import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/academic_calendar_entry.dart';
import '../navigation/app_nav.dart';
import '../providers/academic_calendar_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/nuhris_app_bar.dart';
import '../widgets/dashboard_calendar.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({
    super.key,
    required this.onNavigate,
    required this.onSignOut,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(academicCalendarProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final academicCalendarState = ref.watch(academicCalendarProvider);
    final academicCalendarController = ref.read(
      academicCalendarProvider.notifier,
    );

    if (state.isLoading) {
      return Scaffold(
        drawer: AppDrawer(
          selected: AppNavItem.dashboard,
          onSelect: (item) {
            Navigator.pop(context);
            widget.onNavigate(item);
          },
        ),
        appBar: NuhrisAppBar(
          title: 'Dashboard',
          currentItem: AppNavItem.dashboard,
          onNavigate: widget.onNavigate,
          onSignOut: widget.onSignOut,
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
            widget.onNavigate(item);
          },
        ),
        appBar: NuhrisAppBar(
          title: 'Dashboard',
          currentItem: AppNavItem.dashboard,
          onNavigate: widget.onNavigate,
          onSignOut: widget.onSignOut,
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
    final unreadNotifications = notifications
      .where((notification) => notification['is_read'] != true)
      .toList();

    final employee =
        (dashboard['employee'] as Map?)?.cast<String, dynamic>() ?? {};
    final leaveSummary =
        (dashboard['leave_summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final credentialsSummary =
        (dashboard['credentials_summary'] as Map?)?.cast<String, dynamic>() ??
        {};

    final activeCredentialsCount =
        (credentialsSummary['active_count'] ?? 0) as num;
    final expiringSoonCount =
        (credentialsSummary['expiring_soon_count'] ?? 0) as num;
    final pendingReviewCount =
      (credentialsSummary['pending_review_count'] ?? 0) as num;
    final nonCompliantCount =
        (credentialsSummary['non_compliant_count'] ?? 0) as num;
    final compliantCount =
        (credentialsSummary['compliant_count'] ?? activeCredentialsCount)
            as num;
    final totalCredentialCount =
        (credentialsSummary['total_count'] ?? 0) as num;
    final totalLeaveDays = ((leaveSummary['total_days_remaining'] ?? 0) as num)
        .toDouble();
    // Unread only: derived from notification records where is_read != true.
    final unreadCount = unreadNotifications.length;

    final firstName = (employee['first_name'] ?? '').toString().trim();
    final lastName = (employee['last_name'] ?? '').toString().trim();
    final combinedName = '$firstName $lastName'.trim();
    final fallbackName = (employee['name'] ?? '').toString().trim();
    final welcomeName = combinedName.isNotEmpty
        ? combinedName
        : (fallbackName.isNotEmpty ? fallbackName : 'Employee');

    final complianceValue =
        '${compliantCount.toInt()}/${totalCredentialCount.toInt()}';
    final hasExpiringCredentials = expiringSoonCount.toInt() > 0;
    final metrics = [
      _MetricData(
        title: 'Active Credentials',
        value: activeCredentialsCount.toInt().toString(),
        subtitle: '${pendingReviewCount.toInt()} pending review',
      ),
      _MetricData(
        title: 'Compliance',
        value: complianceValue,
        subtitle: 'Approved and current',
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
        value: unreadCount.toString(),
        subtitle: 'Recent alerts',
      ),
    ];

    return Scaffold(
      drawer: AppDrawer(
        selected: AppNavItem.dashboard,
        onSelect: (item) {
          Navigator.pop(context);
          widget.onNavigate(item);
        },
      ),
      appBar: NuhrisAppBar(
        title: 'Dashboard',
        currentItem: AppNavItem.dashboard,
        onNavigate: widget.onNavigate,
        onSignOut: widget.onSignOut,
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
          final expiryReminder = hasExpiringCredentials
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF4D36B)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE8B3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.notification_important_outlined,
                          color: Color(0xFF9A6700),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You have ${expiringSoonCount.toInt()} approved credential${expiringSoonCount.toInt() == 1 ? '' : 's'} expiring soon.',
                              style: const TextStyle(
                                color: Color(0xFF7A5200),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Please visit your credentials list to review and re-upload the affected document(s) if needed.',
                              style: TextStyle(
                                color: Color(0xFF8C6400),
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink();

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
                        onPressed: () => widget.onNavigate(AppNavItem.notifications),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (unreadNotifications.isEmpty)
                    const Text(
                      'No recent alerts available.',
                      style: TextStyle(color: AppColors.mutedText),
                    )
                  else
                    ...unreadNotifications.take(3).map((n) {
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
              child: academicCalendarState.when(
                loading: () => const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'System Calendar',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              widget.onNavigate(AppNavItem.academicCalendar),
                          child: const Text('Open Calendar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load Academic Calendar: $error',
                      style: const TextStyle(color: AppColors.mutedText),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: academicCalendarController.refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
                data: (calendarData) {
                  final selectedEntries = calendarData.selectedDateEntries;
                  final upcomingEntries = calendarData.upcomingEntries.take(3).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'System Calendar',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                widget.onNavigate(AppNavItem.academicCalendar),
                            child: const Text('Open Calendar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DashboardCalendar(
                        visibleMonth: calendarData.visibleMonth,
                        selectedDay: calendarData.selectedDate,
                        eventDates: calendarData.eventDates,
                        onPreviousMonth: () {
                          academicCalendarController.goToPreviousMonth();
                        },
                        onNextMonth: () {
                          academicCalendarController.goToNextMonth();
                        },
                        onDaySelected: academicCalendarController.selectDate,
                      ),
                      const SizedBox(height: 14),
                      if (selectedEntries.isNotEmpty) ...[
                        const Text(
                          'SELECTED DATE',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mutedText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...selectedEntries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _CalendarEntryDetailCard(entry: entry),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      const Text(
                        'UPCOMING EVENTS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (upcomingEntries.isEmpty)
                        const Text(
                          'No upcoming Academic Calendar events yet.',
                          style: TextStyle(color: AppColors.mutedText),
                        )
                      else
                        ...upcomingEntries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _AcademicUpcomingEventRow(entry: entry),
                          ),
                        ),
                    ],
                  );
                },
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
                if (hasExpiringCredentials)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                    child: expiryReminder,
                  ),
                if (hasExpiringCredentials) const SizedBox(height: 10),
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
                if (hasExpiringCredentials) expiryReminder,
                if (hasExpiringCredentials) const SizedBox(height: 14),
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

class _AcademicUpcomingEventRow extends StatelessWidget {
  const _AcademicUpcomingEventRow({required this.entry});

  final AcademicCalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = entry.isHoliday ? AppColors.orange : AppColors.primaryBlue;
    final dateLabel = DateFormat('MMM d').format(entry.eventDate);

    return _EventRow(
      color: color,
      title: '$dateLabel - ${entry.title} (${entry.entryTypeLabel})',
      subtitle: entry.dayTypeLabel,
    );
  }
}

class _CalendarEntryDetailCard extends StatelessWidget {
  const _CalendarEntryDetailCard({required this.entry});

  final AcademicCalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    final entryColor = entry.isHoliday ? AppColors.orange : AppColors.primaryBlue;
    final dayTypeColor = entry.isNonWorkingDay ? AppColors.red : AppColors.green;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE2ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('MMM d, yyyy').format(entry.eventDate),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mutedText,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniStatusChip(
                label: entry.entryTypeLabel,
                color: entryColor,
              ),
              _MiniStatusChip(
                label: entry.dayTypeLabel,
                color: dayTypeColor,
              ),
            ],
          ),
          if (entry.description != null) ...[
            const SizedBox(height: 8),
            Text(
              entry.description!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2A324A),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStatusChip extends StatelessWidget {
  const _MiniStatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
