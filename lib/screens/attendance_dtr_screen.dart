import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/app_nav.dart';
import '../providers/api_client_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/nuhris_app_bar.dart';

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
      ),
      appBar: NuhrisAppBar(
        title: 'Attendance & DTR',
        currentItem: AppNavItem.attendanceDtr,
        onNavigate: widget.onNavigate,
        onSignOut: widget.onSignOut,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
        children: [
          const Text(
            'View your attendance records, metrics, and DTR.',
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: 13,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
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
                  .where((r) => _displayStatus(r) == 'Absent')
                  .length;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 980;

                  return Column(
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
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
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFD7E0ED)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Daily Time Records',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F1D3A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: 920,
                                  child: Column(
                                    children: [
                                      Container(
                                        color: const Color(0xFFF4F7FC),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 4,
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
                                        const SizedBox(height: 24),
                                        const Center(
                                          child: Text(
                                            'No attendance records found',
                                            style: TextStyle(
                                              color: Color(0xFF9EA3AA),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                      ] else ...[
                                        ...records
                                            .take(20)
                                            .map(
                                              (record) => Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 4,
                                                    ),
                                                decoration:
                                                    const BoxDecoration(
                                                  border: Border(
                                                    bottom: BorderSide(
                                                      color: Color(0xFFE4EAF3),
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
                                                      _formatSchedule(record),
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
                                                      _displayStatus(record),
                                                      flex: 2,
                                                      isStatus: true,
                                                    ),
                                                  ],
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
                      const SizedBox(height: 10),
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

  String _formatSchedule(Map<String, dynamic> record) {
    final inText = _formatTime(record['scheduled_time_in']);
    final outText = _formatTime(record['scheduled_time_out']);
    if (inText == '--' || outText == '--') {
      return 'No schedule';
    }
    return '$inText - $outText';
  }

  String _displayStatus(Map<String, dynamic> record) {
    final raw = (record['status'] ?? '').toString().trim().toLowerCase();
    final scheduleStatus = (record['schedule_status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final noSchedule = _isNoScheduleRecord(record);

    if (scheduleStatus == 'rejected' || scheduleStatus == 'declined') {
      return 'Declined';
    }

    if (noSchedule) {
      return 'No schedule';
    }

    if (raw == 'present') return 'Present';
    if (raw == 'absent') return 'Absent';
    if (raw == 'weekend') return 'Weekend';
    if (raw == 'on_leave' || raw == 'on leave') return 'Non-working day';
    if (raw == 'non-working day' ||
        raw == 'non_working_day' ||
        raw == 'non-working' ||
        raw == 'non working day') {
      return 'Non-working day';
    }

    if (raw.isEmpty) return '-';
    return raw
        .split(RegExp(r'[ _-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  bool _isNoScheduleRecord(Map<String, dynamic> record) {
    final scheduleStatus = (record['schedule_status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (scheduleStatus == 'no_schedule' ||
        scheduleStatus == 'no schedule' ||
        scheduleStatus == 'none' ||
        scheduleStatus == 'pending' ||
        scheduleStatus == 'draft' ||
        scheduleStatus == 'invalid') {
      return true;
    }

    final inText = _formatTime(record['scheduled_time_in']);
    final outText = _formatTime(record['scheduled_time_out']);
    return inText == '--' && outText == '--';
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
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFD7E0ED)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
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
                        fontSize: 12,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
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
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF49556A),
          height: 1.1,
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
    Color statusBg(String value) {
      switch (value) {
        case 'Present':
          return const Color(0xFFDDF5E3);
        case 'Absent':
          return const Color(0xFFFCE0E0);
        case 'Non-working day':
          return const Color(0xFFFFF1D9);
        case 'Weekend':
          return const Color(0xFFE7ECF4);
        case 'Declined':
          return const Color(0xFFFADADD);
        case 'No schedule available':
          return const Color(0xFFECEFF5);
        default:
          return const Color(0xFFECEFF5);
      }
    }

    Color statusFg(String value) {
      switch (value) {
        case 'Present':
          return const Color(0xFF1F8A46);
        case 'Absent':
          return const Color(0xFFC52929);
        case 'Non-working day':
          return const Color(0xFFB7791F);
        case 'Weekend':
          return const Color(0xFF64748B);
        case 'Declined':
          return const Color(0xFFB3261E);
        case 'No schedule available':
          return const Color(0xFF475569);
        default:
          return const Color(0xFF475569);
      }
    }

    return Expanded(
      flex: flex,
      child: isStatus
          ? Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBg(text),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: statusFg(text),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          : Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF303A4D),
                fontWeight: FontWeight.w500,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC8D8FF)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFF245FD2), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Attendance records and DTR are subject to HR review and approval.',
              style: TextStyle(
                color: Color(0xFF245FD2),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
