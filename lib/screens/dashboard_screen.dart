import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/academic_calendar_entry.dart';
import '../navigation/app_nav.dart';
import '../providers/academic_calendar_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/notifications_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/nuhris_app_bar.dart';

/// Palette taken from the web employee dashboard (Tailwind slate/blue/
/// emerald/sky tones) so both clients read the same.
class _WebColors {
  static const heading = Color(0xFF1F2B5D);
  static const title = Color(0xFF1E293B);
  static const muted = Color(0xFF64748B);
  static const cardBorder = Color(0xFFCBD5E1);
  static const softBorder = Color(0xFFE2E8F0);
  static const softBg = Color(0xFFF8FAFC);
  static const link = Color(0xFF1E40AF);

  static const blueBg = Color(0xFFEFF6FF);
  static const blueBorder = Color(0xFFBFDBFE);
  static const blueText = Color(0xFF1D4ED8);
  static const blueStrong = Color(0xFF1E3A8A);

  static const emeraldBg = Color(0xFFECFDF5);
  static const emeraldBorder = Color(0xFFA7F3D0);
  static const emeraldText = Color(0xFF047857);
  static const emeraldStrong = Color(0xFF064E3B);

  static const skyBg = Color(0xFFF0F9FF);
  static const skyBorder = Color(0xFFBAE6FD);
  static const skyText = Color(0xFF0369A1);
}

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
      // The calendar provider is kept alive across screens; retry a previous
      // failure (e.g. Laravel was offline) when the dashboard is reopened.
      if (ref.read(academicCalendarProvider).hasError) {
        ref.read(academicCalendarProvider.notifier).refresh();
      }
    });
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      ref.read(dashboardProvider.notifier).refresh(),
      ref.read(notificationsControllerProvider.notifier).refresh(),
      ref.read(academicCalendarProvider.notifier).refresh(),
    ]);
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
      ),
      appBar: NuhrisAppBar(
        title: 'Dashboard',
        currentItem: AppNavItem.dashboard,
        onNavigate: widget.onNavigate,
        onSignOut: widget.onSignOut,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final pad = isWide ? 24.0 : 16.0;

          final summary = _SummarySection(
            isWide: isWide,
            onNavigate: widget.onNavigate,
          );
          final alerts = _RecentAlertsCard(onNavigate: widget.onNavigate);
          final calendar = _CalendarCard(onNavigate: widget.onNavigate);

          return RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(pad, 20, pad, 24),
              children: [
                const _WelcomeHeader(),
                const SizedBox(height: 16),
                summary,
                const SizedBox(height: 16),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: alerts),
                      const SizedBox(width: 16),
                      Expanded(child: calendar),
                    ],
                  )
                else ...[
                  alerts,
                  const SizedBox(height: 16),
                  calendar,
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// WELCOME
// ============================================================

class _WelcomeHeader extends ConsumerWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardProvider).valueOrNull;
    final name = _displayName(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name == null ? 'Welcome back!' : 'Welcome back, $name!',
          style: const TextStyle(
            color: _WebColors.heading,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Here is an overview of your HR information.',
          style: TextStyle(color: _WebColors.muted, fontSize: 13),
        ),
      ],
    );
  }

  /// The web greets with `users.name`; fall back to the employee record.
  static String? _displayName(Map<String, dynamic>? data) {
    final user = (data?['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final userName = (user['name'] ?? '').toString().trim();
    if (userName.isNotEmpty) return userName;

    final employee =
        (data?['employee'] as Map?)?.cast<String, dynamic>() ?? {};
    final fullName =
        '${employee['first_name'] ?? ''} ${employee['last_name'] ?? ''}'
            .trim();
    return fullName.isEmpty ? null : fullName;
  }
}

// ============================================================
// PRESENT DAYS + QUICK ACCESS
// ============================================================

class _SummarySection extends ConsumerWidget {
  const _SummarySection({required this.isWide, required this.onNavigate});

  final bool isWide;
  final ValueChanged<AppNavItem> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final data = state.valueOrNull;

    final presentDays =
        (data?['present_days'] as Map?)?.cast<String, dynamic>() ?? {};
    final schedule = (data?['latest_approved_schedule'] as Map?)
        ?.cast<String, dynamic>();

    String countText(String key) {
      if (state.isLoading && data == null) return '—';
      if (state.hasError) return '—';
      return ((presentDays[key] as num?) ?? 0).toInt().toString();
    }

    final firstCutoff = _PresentDaysCard(
      label: 'Present Days (1st–15th)',
      value: countText('first_cutoff'),
      caption: 'Current month first cutoff',
    );
    final secondCutoff = _PresentDaysCard(
      label: 'Present Days (16th–End)',
      value: countText('second_cutoff'),
      caption: 'Current month second cutoff',
    );

    final profileLink = _QuickAccessCard(
      title: 'View Your Profile',
      description: 'Open your employee details and degree submissions.',
      background: _WebColors.blueBg,
      border: _WebColors.blueBorder,
      accent: _WebColors.blueText,
      strong: _WebColors.blueStrong,
      onTap: () => onNavigate(AppNavItem.account),
    );
    final scheduleLink = _QuickAccessCard(
      title: 'Approved Schedule',
      description: _scheduleDescription(state, schedule),
      background: _WebColors.emeraldBg,
      border: _WebColors.emeraldBorder,
      accent: _WebColors.emeraldText,
      strong: _WebColors.emeraldStrong,
      onTap: () => onNavigate(AppNavItem.attendanceDtr),
    );

    final error = state.hasError
        ? Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _InlineError(
              message: 'Failed to load attendance summary: ${state.error}',
              onRetry: () => ref.read(dashboardProvider.notifier).refresh(),
            ),
          )
        : const SizedBox.shrink();

    if (isWide) {
      return Column(
        children: [
          error,
          _pair(firstCutoff, secondCutoff),
          const SizedBox(height: 16),
          _pair(profileLink, scheduleLink),
        ],
      );
    }

    return Column(
      children: [
        error,
        _pair(firstCutoff, secondCutoff, gap: 12),
        const SizedBox(height: 12),
        profileLink,
        const SizedBox(height: 12),
        scheduleLink,
      ],
    );
  }

  static Widget _pair(Widget left, Widget right, {double gap = 16}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          SizedBox(width: gap),
          Expanded(child: right),
        ],
      ),
    );
  }

  /// Same wording as the web Quick Access card.
  static String _scheduleDescription(
    AsyncValue<Map<String, dynamic>?> state,
    Map<String, dynamic>? schedule,
  ) {
    if (state.isLoading && !state.hasValue) return 'Loading schedule…';
    if (schedule == null) {
      return 'No approved schedule yet. View schedule status.';
    }
    // Web: `term_label ?? semester_label` (falls back only when null).
    final label = schedule['term_label'] ?? schedule['semester_label'] ?? '';
    return 'Latest: $label';
  }
}

class _PresentDaysCard extends StatelessWidget {
  const _PresentDaysCard({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return _WebCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _WebColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: _WebColors.title,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: const TextStyle(color: _WebColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.title,
    required this.description,
    required this.background,
    required this.border,
    required this.accent,
    required this.strong,
    required this.onTap,
  });

  final String title;
  final String description;
  final Color background;
  final Color border;
  final Color accent;
  final Color strong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Access',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        color: strong,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(color: accent, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// RECENT ALERTS
// ============================================================

class _RecentAlertsCard extends ConsumerWidget {
  const _RecentAlertsCard({required this.onNavigate});

  final ValueChanged<AppNavItem> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);

    final Widget body = state.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _InlineError(
        message: 'Failed to load alerts: $error',
        onRetry: () =>
            ref.read(notificationsControllerProvider.notifier).refresh(),
      ),
      data: (items) {
        // Web: visible notifications, latest first, limit 3.
        final recent = items.where((n) => n.isVisible).take(3).toList();
        if (recent.isEmpty) {
          return const _SoftTile(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No recent alerts',
                  style: TextStyle(
                    color: _WebColors.title,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'You are all caught up.',
                  style: TextStyle(color: _WebColors.muted, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            for (final item in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AlertTile(
                  item: item,
                  onTap: () => onNavigate(AppNavItem.notifications),
                ),
              ),
          ],
        );
      },
    );

    return _WebCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Alerts',
                  style: TextStyle(
                    color: _WebColors.title,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => onNavigate(AppNavItem.notifications),
                style: TextButton.styleFrom(
                  foregroundColor: _WebColors.link,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          body,
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final priority = item.priority;
    final (badgeBg, badgeFg) = switch (priority) {
      'low' => (const Color(0xFFD1FAE5), const Color(0xFF047857)),
      'medium' => (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
      'high' => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      _ => (const Color(0xFFF1F5F9), const Color(0xFF334155)),
    };
    final priorityLabel =
        '${priority[0].toUpperCase()}${priority.substring(1)}';

    return _SoftTile(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    color: _WebColors.title,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Badge(label: priorityLabel, background: badgeBg, color: badgeFg),
              if (item.isExpired) ...[
                const SizedBox(width: 6),
                const _Badge(
                  label: 'Expired',
                  background: Color(0xFFFEF3C7),
                  color: Color(0xFFB45309),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('MMM dd, hh:mm a').format(item.createdAt.toLocal()),
            style: const TextStyle(color: _WebColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CALENDAR
// ============================================================

class _CalendarCard extends ConsumerWidget {
  const _CalendarCard({required this.onNavigate});

  final ValueChanged<AppNavItem> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(academicCalendarProvider);

    final Widget upcoming = state.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _InlineError(
        message: 'Failed to load Academic Calendar: $error',
        onRetry: () => ref.read(academicCalendarProvider.notifier).refresh(),
      ),
      data: (calendar) {
        final entries = calendar.upcomingEntries.take(3).toList();
        if (entries.isEmpty) {
          return const Text(
            'No upcoming academic calendar entries yet.',
            style: TextStyle(color: _WebColors.muted, fontSize: 13),
          );
        }
        return Column(
          children: [
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _UpcomingEntryTile(entry: entry),
              ),
          ],
        );
      },
    );

    return _WebCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calendar',
                      style: TextStyle(
                        color: _WebColors.title,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Browse the academic calendar by month.',
                      style: TextStyle(color: _WebColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => onNavigate(AppNavItem.academicCalendar),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _WebColors.skyText,
                  backgroundColor: _WebColors.skyBg,
                  side: const BorderSide(color: _WebColors.skyBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Open Calendar'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _WebColors.softBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _WebColors.softBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'UPCOMING ACADEMIC DATES',
                  style: TextStyle(
                    color: _WebColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 12),
                upcoming,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingEntryTile extends StatelessWidget {
  const _UpcomingEntryTile({required this.entry});

  final AcademicCalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _WebColors.blueBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _WebColors.blueBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.title,
            style: const TextStyle(
              color: _WebColors.title,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${DateFormat('MMM dd, yyyy').format(entry.eventDate)} · '
            '${entry.entryTypeLabel}',
            style: const TextStyle(color: _WebColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SHARED PIECES
// ============================================================

class _WebCard extends StatelessWidget {
  const _WebCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _WebColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SoftTile extends StatelessWidget {
  const _SoftTile({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _WebColors.softBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _WebColors.softBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.color,
  });

  final String label;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
        ),
        const SizedBox(height: 4),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
