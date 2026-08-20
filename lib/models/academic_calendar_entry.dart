import 'package:flutter/material.dart';

class AcademicCalendarEntry {
  const AcademicCalendarEntry({
    required this.id,
    required this.title,
    required this.entryType,
    required this.dayType,
    required this.eventDate,
    this.description,
  });

  final int id;
  final String title;
  final String entryType;
  final String dayType;
  final DateTime eventDate;
  final String? description;

  factory AcademicCalendarEntry.fromJson(Map<String, dynamic> json) {
    final parsedDate = DateTime.tryParse(
      (json['event_date'] ?? '').toString().trim(),
    );
    if (parsedDate == null) {
      throw const FormatException('Academic calendar entry is missing event_date.');
    }

    return AcademicCalendarEntry(
      id: _parseInt(json['id']),
      title: (json['title'] ?? '').toString().trim(),
      entryType: (json['entry_type'] ?? '').toString().trim().toLowerCase(),
      dayType: (json['day_type'] ?? '').toString().trim().toLowerCase(),
      eventDate: DateUtils.dateOnly(parsedDate),
      description: _parseOptionalText(json['description']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _parseOptionalText(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }

  bool get isHoliday => entryType == 'holiday';
  bool get isEvent => entryType == 'event';
  bool get isWorkingDay => dayType == 'working';
  bool get isNonWorkingDay => dayType == 'non_working';

  String get entryTypeLabel {
    switch (entryType) {
      case 'holiday':
        return 'Holiday';
      case 'event':
        return 'Event';
      default:
        return _titleCase(entryType);
    }
  }

  String get dayTypeLabel {
    switch (dayType) {
      case 'working':
        return 'Working';
      case 'non_working':
        return 'Non-Working';
      default:
        return _titleCase(dayType.replaceAll('_', ' '));
    }
  }

  static String _titleCase(String value) {
    final words = value
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}');
    return words.join(' ');
  }
}
