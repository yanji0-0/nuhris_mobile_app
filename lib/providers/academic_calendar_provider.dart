import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/academic_calendar_entry.dart';
import 'api_client_provider.dart';

final academicCalendarProvider =
    AsyncNotifierProvider<AcademicCalendarController, AcademicCalendarState>(
      AcademicCalendarController.new,
    );

class AcademicCalendarController extends AsyncNotifier<AcademicCalendarState> {
  @override
  Future<AcademicCalendarState> build() async {
    return _buildState();
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _buildState(
        visibleMonth: current?.visibleMonth,
        selectedDate: current?.selectedDate,
      ),
    );
  }

  Future<void> goToPreviousMonth() async {
    await _setVisibleMonthDelta(-1);
  }

  Future<void> goToNextMonth() async {
    await _setVisibleMonthDelta(1);
  }

  void selectDate(DateTime date) {
    final current = state.valueOrNull;
    if (current == null) return;

    final normalized = _normalizeDate(date);
    state = AsyncData(
      current.copyWith(
        visibleMonth: DateTime(normalized.year, normalized.month, 1),
        selectedDate: normalized,
      ),
    );
  }

  Future<AcademicCalendarState> _buildState({
    DateTime? visibleMonth,
    DateTime? selectedDate,
  }) async {
    final api = ref.read(apiClientProvider);
    final entries = await api.getAcademicCalendarEntries();
    final now = DateTime.now();
    final resolvedVisibleMonth = DateTime(
      (visibleMonth ?? now).year,
      (visibleMonth ?? now).month,
      1,
    );
    final resolvedSelectedDate = _resolveSelectedDate(
      entries: entries,
      visibleMonth: resolvedVisibleMonth,
      selectedDate: selectedDate ?? now,
    );

    return AcademicCalendarState(
      entries: entries,
      visibleMonth: resolvedVisibleMonth,
      selectedDate: resolvedSelectedDate,
    );
  }

  Future<void> _setVisibleMonthDelta(int delta) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final nextMonth = DateTime(
      current.visibleMonth.year,
      current.visibleMonth.month + delta,
      1,
    );
    final selected = _resolveSelectedDate(
      entries: current.entries,
      visibleMonth: nextMonth,
      selectedDate: DateTime(nextMonth.year, nextMonth.month, 1),
    );

    state = AsyncData(
      current.copyWith(visibleMonth: nextMonth, selectedDate: selected),
    );
  }

  DateTime _resolveSelectedDate({
    required List<AcademicCalendarEntry> entries,
    required DateTime visibleMonth,
    required DateTime selectedDate,
  }) {
    final normalizedSelected = _normalizeDate(selectedDate);
    if (_isSameMonth(normalizedSelected, visibleMonth)) {
      return normalizedSelected;
    }

    final monthEntries = entries
        .where((entry) => _isSameMonth(entry.eventDate, visibleMonth))
        .toList()
      ..sort((left, right) => left.eventDate.compareTo(right.eventDate));

    if (monthEntries.isNotEmpty) {
      return monthEntries.first.eventDate;
    }

    return DateTime(visibleMonth.year, visibleMonth.month, 1);
  }

  static bool _isSameMonth(DateTime left, DateTime right) {
    return left.year == right.year && left.month == right.month;
  }

  static DateTime _normalizeDate(DateTime date) {
    return DateUtils.dateOnly(date);
  }
}

class AcademicCalendarState {
  AcademicCalendarState({
    required this.entries,
    required this.visibleMonth,
    required this.selectedDate,
  }) : entriesByDate = _groupEntriesByDate(entries);

  final List<AcademicCalendarEntry> entries;
  final DateTime visibleMonth;
  final DateTime selectedDate;
  final Map<DateTime, List<AcademicCalendarEntry>> entriesByDate;

  Set<DateTime> get eventDates => entriesByDate.keys.toSet();

  List<AcademicCalendarEntry> get selectedDateEntries =>
      entriesByDate[_normalizeDate(selectedDate)] ?? const [];

  List<AcademicCalendarEntry> get visibleMonthEntries => entries
      .where((entry) => _isSameMonth(entry.eventDate, visibleMonth))
      .toList()
    ..sort((left, right) => left.eventDate.compareTo(right.eventDate));

  List<AcademicCalendarEntry> get upcomingEntries {
    final today = _normalizeDate(DateTime.now());
    return entries.where((entry) {
      return !entry.eventDate.isBefore(today);
    }).toList()
      ..sort((left, right) => left.eventDate.compareTo(right.eventDate));
  }

  AcademicCalendarState copyWith({
    List<AcademicCalendarEntry>? entries,
    DateTime? visibleMonth,
    DateTime? selectedDate,
  }) {
    return AcademicCalendarState(
      entries: entries ?? this.entries,
      visibleMonth: visibleMonth ?? this.visibleMonth,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }

  static Map<DateTime, List<AcademicCalendarEntry>> _groupEntriesByDate(
    List<AcademicCalendarEntry> entries,
  ) {
    final grouped = <DateTime, List<AcademicCalendarEntry>>{};
    for (final entry in entries) {
      final key = _normalizeDate(entry.eventDate);
      grouped.putIfAbsent(key, () => <AcademicCalendarEntry>[]).add(entry);
    }
    return grouped;
  }

  static bool _isSameMonth(DateTime left, DateTime right) {
    return left.year == right.year && left.month == right.month;
  }

  static DateTime _normalizeDate(DateTime date) {
    return DateUtils.dateOnly(date);
  }
}
