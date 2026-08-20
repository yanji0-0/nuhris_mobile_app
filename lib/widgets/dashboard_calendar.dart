import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardCalendar extends StatelessWidget {
  const DashboardCalendar({
    super.key,
    required this.visibleMonth,
    required this.selectedDay,
    required this.eventDates,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDaySelected,
  });

  final DateTime visibleMonth;
  final DateTime? selectedDay;
  final Set<DateTime> eventDates;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDaySelected;

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return _isSameDay(date, DateTime(now.year, now.month, now.day));
  }

  /// Returns 42 items (6 rows x 7 cols) for a full month view.
  List<DateTime> _calendarDaysForMonth(DateTime month) {
    final firstOfMonth = DateTime(month.year, month.month, 1);

    // DateTime.weekday: Mon=1 ... Sun=7
    // We want calendar starting on Monday.
    final int daysBefore = firstOfMonth.weekday - DateTime.monday;
    final DateTime firstGridDay = firstOfMonth.subtract(Duration(days: daysBefore));

    return List.generate(
      42,
      (index) => DateTime(
        firstGridDay.year,
        firstGridDay.month,
        firstGridDay.day + index,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _calendarDaysForMonth(visibleMonth);
    final monthLabel = DateFormat('MMMM yyyy').format(visibleMonth);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 3),
            color: Color(0x11000000),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    monthLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Weekday labels (Mon-Sun)
          Row(
            children: const [
              _WeekdayLabel('Mon'),
              _WeekdayLabel('Tue'),
              _WeekdayLabel('Wed'),
              _WeekdayLabel('Thu'),
              _WeekdayLabel('Fri'),
              _WeekdayLabel('Sat'),
              _WeekdayLabel('Sun'),
            ],
          ),
          const SizedBox(height: 8),

          // Month grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              final normalizedDay = DateUtils.dateOnly(day);
              final inCurrentMonth = day.month == visibleMonth.month;
              final isSelected = selectedDay != null && _isSameDay(day, selectedDay!);
              final isToday = _isToday(day);
              final hasEvents = eventDates.any((date) => _isSameDay(date, normalizedDay));

              Color bgColor = Colors.transparent;
              Color textColor = inCurrentMonth ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF);
              FontWeight fw = FontWeight.w500;

              if (isSelected) {
                bgColor = const Color(0xFF2563EB);
                textColor = Colors.white;
                fw = FontWeight.w700;
              } else if (isToday) {
                bgColor = const Color(0xFFE5EDFF);
                textColor = const Color(0xFF1D4ED8);
                fw = FontWeight.w700;
              }

              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  onDaySelected(day);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isToday && !isSelected
                          ? const Color(0xFFBFDBFE)
                          : hasEvents
                          ? const Color(0xFFBFDBFE)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: fw,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        height: 6,
                        child: hasEvents
                            ? Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String text;
  const _WeekdayLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}