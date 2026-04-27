import 'package:flutter/material.dart';
import '../navigation/app_nav.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';

class AttendanceDtrScreen extends StatefulWidget {
  const AttendanceDtrScreen({
    super.key,
    required this.onNavigate,
    required this.onSignOut,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;

  @override
  State<AttendanceDtrScreen> createState() => _AttendanceDtrScreenState();
}

class _AttendanceDtrScreenState extends State<AttendanceDtrScreen> {
  String selectedRecord = 'All Records';
  final List<String> recordFilters = const ['All Records'];
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.instance.getAttendanceDtr();
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

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'Tardiness',
                          value: '${tardiness}m',
                          icon: Icons.access_time,
                          iconColor: const Color(0xFFDD6B20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          title: 'Undertime',
                          value: '${undertime}m',
                          icon: Icons.show_chart,
                          iconColor: const Color(0xFF2F9E44),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'Overtime',
                          value: '${overtime}m',
                          icon: Icons.watch_later_outlined,
                          iconColor: const Color(0xFF0B3A6E),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          title: 'Absences',
                          value: absences.toString(),
                          icon: Icons.warning_amber_rounded,
                          iconColor: const Color(0xFFE03131),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'Records',
                          value: records.length.toString(),
                          icon: Icons.event_note_outlined,
                          iconColor: const Color(0xFF6F42C1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Time Records',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4B4B4B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: selectedRecord,
                            isExpanded: true,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF1F1F1),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD0D0D0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                                borderSide: const BorderSide(
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ),
                            items: recordFilters
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(v),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => selectedRecord = v);
                            },
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            color: const Color(0xFFD8D8D8),
                            padding: const EdgeInsets.symmetric(
                              vertical: 9,
                              horizontal: 6,
                            ),
                            child: const Row(
                              children: [
                                _HeadCell('Date', flex: 2),
                                _HeadCell('Time\nIn', flex: 2),
                                _HeadCell('Time\nOut', flex: 2),
                                _HeadCell('Scheduled', flex: 2),
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
                            const SizedBox(height: 8),
                            ...records
                                .take(20)
                                .map(
                                  (record) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        _BodyCell(
                                          _formatDate(record['record_date']),
                                          flex: 2,
                                        ),
                                        _BodyCell(
                                          _formatTime(record['time_in']),
                                          flex: 2,
                                        ),
                                        _BodyCell(
                                          _formatTime(record['time_out']),
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
                                          _toInt(
                                            record['overtime_minutes'],
                                          ).toString(),
                                          flex: 1,
                                        ),
                                        _BodyCell(
                                          (record['status'] ?? '').toString(),
                                          flex: 2,
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
    if (text.length >= 10) {
      return text.substring(0, 10);
    }
    return text;
  }

  String _formatTime(Object? value) {
    final text = (value ?? '').toString();
    if (text.isEmpty || text == 'null') {
      return '--';
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
  });
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final titleSize = width < 380 ? 19.0 : 20.0;
    final valueSize = width < 380 ? 56.0 : 58.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 138),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: titleSize,
                        color: const Color(0xFF4A4A4A),
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(icon, color: iconColor, size: 28),
                ],
              ),
              const SizedBox(height: 14),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: valueSize,
                    color: const Color(0xFF2B2D2F),
                    height: 0.9,
                  ),
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
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Color(0xFF686868),
          height: 1.05,
        ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell(this.text, {required this.flex});

  final String text;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 10, color: Color(0xFF444444)),
      ),
    );
  }
}
