import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/app_nav.dart';
import '../services/api_client.dart';
import '../providers/api_client_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';

class AttendanceDtrScreen extends ConsumerStatefulWidget {
  const AttendanceDtrScreen({
    super.key,
    required this.onNavigate,
    required this.onSignOut,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;

  @override
  ConsumerState<AttendanceDtrScreen> createState() =>
      _AttendanceDtrScreenState();
}

class _AttendanceDtrScreenState extends ConsumerState<AttendanceDtrScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiClientProvider).getAttendanceDtr();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        selected: AppNavItem.attendanceDtr,
        onSelect: (item) {
          Navigator.pop(context);
          widget.onNavigate(item);
        },
        onSignOut: widget.onSignOut,
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1B66),
        foregroundColor: Colors.white,
        surfaceTintColor: const Color(0xFF0A1B66),
        elevation: 0,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('Attendance & DTR'),
        actions: [
          IconButton(
            onPressed: () => widget.onNavigate(AppNavItem.notifications),
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
        children: [
          const Text(
            'View your attendance records, computed metrics, and DTR.',
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: 14,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text('Failed to load records: ${snapshot.error}'),
                  ),
                );
              }

              final records = snapshot.data ?? const [];
              final tardiness = records.fold<int>(
                0,
                (sum, r) => sum + _toInt(r['tardiness_minutes']),
              );
              final undertime = records.fold<int>(
                0,
                (sum, r) => sum + _toInt(r['undertime_minutes']),
              );
              final overtime = records.fold<int>(
                0,
                (sum, r) => sum + _toInt(r['overtime_minutes']),
              );
              final absences = records
                  .where((r) => (r['status'] ?? '').toString() == 'absent')
                  .length;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final showMobileSchedule = constraints.maxWidth < 700;
                  final isCompact = constraints.maxWidth < 980;

                  return Column(
                    children: [
                      if (showMobileSchedule) ...[
                        const _WeeklyScheduleComposer(),
                        const SizedBox(height: 18),
                      ],
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _MetricCard(
                            title: 'Tardiness',
                            value: '${tardiness}m',
                            icon: Icons.access_time,
                            iconColor: const Color(0xFF245FD2),
                            iconBackground: const Color(0xFFE9EFFD),
                            width: isCompact
                                ? (constraints.maxWidth - 10) / 2
                                : (constraints.maxWidth - 20) / 3,
                          ),
                          _MetricCard(
                            title: 'Undertime',
                            value: '${undertime}m',
                            icon: Icons.schedule,
                            iconColor: const Color(0xFF1E9A63),
                            iconBackground: const Color(0xFFEAF7F1),
                            width: isCompact
                                ? (constraints.maxWidth - 10) / 2
                                : (constraints.maxWidth - 20) / 3,
                          ),
                          _MetricCard(
                            title: 'Overtime',
                            value: '${overtime}m',
                            icon: Icons.watch_later_outlined,
                            iconColor: const Color(0xFFF08C00),
                            iconBackground: const Color(0xFFFEF4E7),
                            width: isCompact
                                ? (constraints.maxWidth - 10) / 2
                                : (constraints.maxWidth - 20) / 3,
                          ),
                          _MetricCard(
                            title: 'Absences',
                            value: absences.toString(),
                            icon: Icons.warning_amber_rounded,
                            iconColor: const Color(0xFFE03131),
                            iconBackground: const Color(0xFFFDECEC),
                            width: isCompact
                                ? (constraints.maxWidth - 10) / 2
                                : (constraints.maxWidth - 10) / 2,
                          ),
                          _MetricCard(
                            title: 'Workload Credits',
                            value: records.length.toString(),
                            icon: Icons.event_note_outlined,
                            iconColor: const Color(0xFF7B3FE4),
                            iconBackground: const Color(0xFFF2ECFE),
                            width: isCompact
                                ? (constraints.maxWidth - 10) / 2
                                : (constraints.maxWidth - 10) / 2,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: Color(0xFFD7E0ED)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Daily Time Records',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F1D3A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: 920,
                                  child: Column(
                                    children: [
                                      Container(
                                        color: const Color(0xFFF4F7FC),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 6,
                                        ),
                                        child: const Row(
                                          children: [
                                            _HeadCell('Date', flex: 2),
                                            _HeadCell('Time In', flex: 2),
                                            _HeadCell('Time Out', flex: 2),
                                            _HeadCell('Sched.', flex: 2),
                                            _HeadCell('Tardiness', flex: 2),
                                            _HeadCell('Undertime', flex: 2),
                                            _HeadCell('OT', flex: 1),
                                            _HeadCell('Status', flex: 2),
                                          ],
                                        ),
                                      ),
                                      if (records.isEmpty) ...[
                                        const SizedBox(height: 36),
                                        const Center(
                                          child: Text(
                                            'No attendance records found',
                                            style: TextStyle(
                                              color: Color(0xFF9EA3AA),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 36),
                                      ] else ...[
                                        const SizedBox(height: 6),
                                        ...records
                                            .take(20)
                                            .map(
                                              (record) => Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 2,
                                                    ),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 10,
                                                        horizontal: 4,
                                                      ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        border: Border(
                                                          bottom: BorderSide(
                                                            color: Color(
                                                              0xFFE4EAF3,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      _BodyCell(
                                                        _formatDate(
                                                          record['record_date'],
                                                        ),
                                                        flex: 2,
                                                      ),
                                                      _BodyCell(
                                                        _formatTime(
                                                          record['time_in'],
                                                        ),
                                                        flex: 2,
                                                      ),
                                                      _BodyCell(
                                                        _formatTime(
                                                          record['time_out'],
                                                        ),
                                                        flex: 2,
                                                      ),
                                                      _BodyCell(
                                                        '${_formatTime(record['scheduled_time_in'])} - ${_formatTime(record['scheduled_time_out'])}',
                                                        flex: 2,
                                                      ),
                                                      _BodyCell(
                                                        '${_toInt(record['tardiness_minutes'])}m',
                                                        flex: 2,
                                                      ),
                                                      _BodyCell(
                                                        '${_toInt(record['undertime_minutes'])}m',
                                                        flex: 2,
                                                      ),
                                                      _BodyCell(
                                                        '${_toInt(record['overtime_minutes'])}m',
                                                        flex: 1,
                                                      ),
                                                      _BodyCell(
                                                        (record['status'] ?? '')
                                                            .toString(),
                                                        flex: 2,
                                                        isStatus: true,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _AttendanceInfoBanner(),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  int _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatDate(Object? value) {
    final text = (value ?? '').toString();
    if (text.length < 10) {
      return text;
    }

    final datePortion = text.substring(0, 10);
    final parsed = DateTime.tryParse(datePortion);
    if (parsed == null) {
      return datePortion;
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[parsed.month - 1]} ${parsed.day.toString().padLeft(2, '0')}, ${parsed.year}';
  }

  String _formatTime(Object? value) {
    final text = (value ?? '').toString();
    if (text.isEmpty || text == 'null') {
      return '--';
    }

    // Convert 24-hour backend values (e.g. 19:00:00) to 12-hour format.
    final parts = text.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        final suffix = hour >= 12 ? 'PM' : 'AM';
        final hour12 = hour % 12 == 0 ? 12 : hour % 12;
        return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $suffix';
      }
    }

    return text;
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.width,
  });
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFD7E0ED)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 22 / 2,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 44 / 2,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeadCell extends StatelessWidget {
  const _HeadCell(this.text, {required this.flex});
  final String text;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 22 / 2,
          fontWeight: FontWeight.w700,
          color: Color(0xFF49556A),
          height: 1.05,
        ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell(this.text, {required this.flex, this.isStatus = false});

  final String text;
  final int flex;
  final bool isStatus;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: isStatus ? const Color(0xFF1E9A63) : const Color(0xFF303A4D),
          fontWeight: isStatus ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _AttendanceInfoBanner extends StatelessWidget {
  const _AttendanceInfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC8D8FF)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: const Row(
        children: [
          Icon(Icons.info, color: Color(0xFF245FD2), size: 30),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Attendance records and DTR are subject to HR review and approval.',
              style: TextStyle(
                color: Color(0xFF245FD2),
                fontSize: 24 / 2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyScheduleComposer extends ConsumerStatefulWidget {
  const _WeeklyScheduleComposer();

  @override
  ConsumerState<_WeeklyScheduleComposer> createState() =>
      _WeeklyScheduleComposerState();
}

class _WeeklyScheduleComposerState extends ConsumerState<_WeeklyScheduleComposer> {
  static const List<String> _terms = ['1st Term', '2nd Term', '3rd Term'];

  late String _selectedTerm;
  late final List<_ScheduleDayState> _days;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedTerm = _terms.last;
    _days = [
      _ScheduleDayState(
        key: 'monday',
        dayIndex: 1,
        label: 'Monday',
        mode: _ScheduleMode.withWork,
      ),
      _ScheduleDayState(
        key: 'tuesday',
        dayIndex: 2,
        label: 'Tuesday',
        mode: _ScheduleMode.noWork,
      ),
      _ScheduleDayState(
        key: 'wednesday',
        dayIndex: 3,
        label: 'Wednesday',
        mode: _ScheduleMode.withWork,
      ),
      _ScheduleDayState(
        key: 'thursday',
        dayIndex: 4,
        label: 'Thursday',
        mode: _ScheduleMode.noWork,
      ),
      _ScheduleDayState(
        key: 'friday',
        dayIndex: 5,
        label: 'Friday',
        mode: _ScheduleMode.noWork,
      ),
      _ScheduleDayState(
        key: 'saturday',
        dayIndex: 6,
        label: 'Saturday',
        mode: _ScheduleMode.noWork,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WEEKLY SCHEDULE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.12,
                color: Color(0xFF0B67B2),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Submit your Monday to Saturday schedule',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.1,
                color: Color(0xFF10233B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Mark each day as With Work or No Work. HR approval is required before this schedule becomes the DTR reference.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD8E3F0)),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current submission',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedTerm,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10233B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Status: Draft',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Term',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedTerm,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primaryBlue),
                ),
              ),
              items: _terms
                  .map(
                    (term) => DropdownMenuItem(value: term, child: Text(term)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _selectedTerm = value);
              },
            ),
            const SizedBox(height: 12),
            ..._days.map(
              (day) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ScheduleDayCard(
                  day: day,
                  onModeChanged: (mode) {
                    setState(() => day.mode = mode);
                  },
                  onTimePicked: (which) async {
                    final initial = which == _ScheduleTimeField.timeIn
                        ? day.timeIn ?? const TimeOfDay(hour: 7, minute: 0)
                        : day.timeOut ?? const TimeOfDay(hour: 17, minute: 0);
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: initial,
                    );
                    if (picked == null) {
                      return;
                    }
                    setState(() {
                      if (which == _ScheduleTimeField.timeIn) {
                        day.timeIn = picked;
                      } else {
                        day.timeOut = picked;
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmitting ? null : _reset,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00386f),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    _isSubmitting ? 'Submitting...' : 'Submit Schedule to HR',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _reset() {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _selectedTerm = _terms.last;
      for (final day in _days) {
        day.mode = day.label == 'Monday' || day.label == 'Wednesday'
            ? _ScheduleMode.withWork
            : _ScheduleMode.noWork;
        day.timeIn = null;
        day.timeOut = null;
      }
    });
  }

  void _submit() {
    final missingDay = _days.firstWhere(
      (day) => day.isWithWork && (day.timeIn == null || day.timeOut == null),
      orElse: () => _ScheduleDayState(
        key: '',
        dayIndex: 0,
        label: '',
        mode: _ScheduleMode.noWork,
      ),
    );

    if (missingDay.label.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Set Time In and Time Out for ${missingDay.label}.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final payload = _days
        .map(
          (day) => <String, dynamic>{
            'day_name': day.label,
            'day_index': day.dayIndex,
            'has_work': day.mode == _ScheduleMode.withWork,
            'time_in': day.timeIn == null
                ? null
                : _formatTimeOfDay(day.timeIn!),
            'time_out': day.timeOut == null
                ? null
                : _formatTimeOfDay(day.timeOut!),
          },
        )
        .toList();

    final api = ref.read(apiClientProvider);
    api
        .submitEmployeeSchedule(termLabel: _selectedTerm, days: payload)
        .then((result) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message']?.toString() ??
                    'Schedule submitted successfully.',
              ),
            ),
          );
        })
        .catchError((error) {
          if (!mounted) {
            return;
          }
          final message = error is ApiException
              ? error.message
              : error.toString();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        })
        .whenComplete(() {
          if (mounted) {
            setState(() => _isSubmitting = false);
          }
        });
  }

  String _formatTimeOfDay(TimeOfDay timeOfDay) {
    final hours = timeOfDay.hour.toString().padLeft(2, '0');
    final minutes = timeOfDay.minute.toString().padLeft(2, '0');
    return '$hours:$minutes:00';
  }
}

enum _ScheduleMode { withWork, noWork }

enum _ScheduleTimeField { timeIn, timeOut }

class _ScheduleDayState {
  _ScheduleDayState({
    required this.key,
    required this.dayIndex,
    required this.label,
    required this.mode,
  });

  final String key;
  final int dayIndex;
  final String label;
  _ScheduleMode mode;
  TimeOfDay? timeIn;
  TimeOfDay? timeOut;

  bool get isWithWork => mode == _ScheduleMode.withWork;
}

class _ScheduleDayCard extends StatelessWidget {
  const _ScheduleDayCard({
    required this.day,
    required this.onModeChanged,
    required this.onTimePicked,
  });

  final _ScheduleDayState day;
  final ValueChanged<_ScheduleMode> onModeChanged;
  final Future<void> Function(_ScheduleTimeField which) onTimePicked;

  @override
  Widget build(BuildContext context) {
    final withWorkSelected = day.mode == _ScheduleMode.withWork;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7E0ED)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  day.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF10233B),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ModePillButton(
                    label: 'With Work',
                    selected: withWorkSelected,
                    selectedColor: const Color(0xFF16A34A),
                    textColor: const Color(0xFF16A34A),
                    selectedTextColor: Colors.white,
                    onTap: () => onModeChanged(_ScheduleMode.withWork),
                  ),
                  const SizedBox(width: 6),
                  _ModePillButton(
                    label: 'No Work',
                    selected: !withWorkSelected,
                    selectedColor: const Color(0xFFDC2626),
                    textColor: const Color(0xFFDC2626),
                    selectedTextColor: Colors.white,
                    onTap: () => onModeChanged(_ScheduleMode.noWork),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (withWorkSelected)
            Row(
              children: [
                Expanded(
                  child: _TimePickerField(
                    label: 'Time In',
                    value: day.timeIn,
                    onTap: () => onTimePicked(_ScheduleTimeField.timeIn),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TimePickerField(
                    label: 'Time Out',
                    value: day.timeOut,
                    onTap: () => onTimePicked(_ScheduleTimeField.timeOut),
                  ),
                ),
              ],
            )
          else
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFDF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFBCACA)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: const Text(
                'Time inputs are disabled for no-work days.',
                style: TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModePillButton extends StatelessWidget {
  const _ModePillButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.textColor,
    required this.selectedTextColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final Color textColor;
  final Color selectedTextColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? selectedColor : const Color(0xFFD1D5DB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? selectedTextColor : textColor,
          ),
        ),
      ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final TimeOfDay? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timeText = value == null
        ? '--:-- --'
        : MaterialLocalizations.of(context).formatTimeOfDay(value!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 42,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    timeText,
                    style: TextStyle(
                      fontSize: 13,
                      color: value == null
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.access_time,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
