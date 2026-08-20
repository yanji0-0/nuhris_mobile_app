import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/academic_calendar_entry.dart';
import '../navigation/app_nav.dart';
import '../providers/academic_calendar_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/dashboard_calendar.dart';
import '../widgets/nuhris_app_bar.dart';

class AcademicCalendarScreen extends ConsumerStatefulWidget {
  const AcademicCalendarScreen({
    super.key,
    required this.onNavigate,
    required this.onSignOut,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;

  @override
  ConsumerState<AcademicCalendarScreen> createState() =>
      _AcademicCalendarScreenState();
}

class _AcademicCalendarScreenState
    extends ConsumerState<AcademicCalendarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(academicCalendarProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final calendarState = ref.watch(academicCalendarProvider);
    final controller = ref.read(academicCalendarProvider.notifier);

    return Scaffold(
      drawer: AppDrawer(
        selected: AppNavItem.academicCalendar,
        onSelect: (item) {
          Navigator.pop(context);
          widget.onNavigate(item);
        },
      ),
      appBar: NuhrisAppBar(
        title: 'Academic Calendar',
        currentItem: AppNavItem.academicCalendar,
        onNavigate: widget.onNavigate,
        onSignOut: widget.onSignOut,
      ),
      body: calendarState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Failed to load Academic Calendar: $error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: controller.refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          final monthLabel = DateFormat('MMMM yyyy').format(data.visibleMonth);
          final selectedEntries = data.selectedDateEntries;
          final monthEntries = data.visibleMonthEntries;

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Academic Calendar',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DashboardCalendar(
                          visibleMonth: data.visibleMonth,
                          selectedDay: data.selectedDate,
                          eventDates: data.eventDates,
                          onPreviousMonth: () {
                            controller.goToPreviousMonth();
                          },
                          onNextMonth: () {
                            controller.goToNextMonth();
                          },
                          onDaySelected: controller.selectDate,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _SelectedDateEventsSection(
                      selectedDate: data.selectedDate,
                      entries: selectedEntries,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EVENTS IN $monthLabel'.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mutedText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (monthEntries.isEmpty)
                          const Text(
                            'No Academic Calendar entries for this month.',
                            style: TextStyle(color: AppColors.mutedText),
                          )
                        else
                          ...monthEntries.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _AcademicCalendarEntryCard(entry: entry),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SelectedDateEventsSection extends StatelessWidget {
  const _SelectedDateEventsSection({
    required this.selectedDate,
    required this.entries,
  });

  final DateTime selectedDate;
  final List<AcademicCalendarEntry> entries;

  @override
  Widget build(BuildContext context) {
    final heading = DateFormat('MMMM d, yyyy').format(selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const Text(
            'No Academic Calendar events for this date.',
            style: TextStyle(color: AppColors.mutedText),
          )
        else
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AcademicCalendarEntryCard(entry: entry),
            ),
          ),
      ],
    );
  }
}

class _AcademicCalendarEntryCard extends StatelessWidget {
  const _AcademicCalendarEntryCard({required this.entry});

  final AcademicCalendarEntry entry;

  Color get _entryColor {
    if (entry.isHoliday) return AppColors.orange;
    return AppColors.primaryBlue;
  }

  Color get _dayTypeColor {
    if (entry.isNonWorkingDay) return AppColors.red;
    return AppColors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE2ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(
                label: entry.entryTypeLabel,
                backgroundColor: _entryColor.withValues(alpha: 0.14),
                textColor: _entryColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('MMM d, yyyy').format(entry.eventDate),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(
                label: entry.dayTypeLabel,
                backgroundColor: _dayTypeColor.withValues(alpha: 0.14),
                textColor: _dayTypeColor,
              ),
            ],
          ),
          if (entry.description != null) ...[
            const SizedBox(height: 10),
            Text(
              entry.description!,
              style: const TextStyle(
                fontSize: 13,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
