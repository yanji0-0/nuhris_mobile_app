import 'package:flutter/material.dart';
import '../navigation/app_nav.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';

class AttendanceDtrScreen extends StatefulWidget {
  const AttendanceDtrScreen({super.key, required this.onNavigate});

  final ValueChanged<AppNavItem> onNavigate;

  @override
  State<AttendanceDtrScreen> createState() => _AttendanceDtrScreenState();
}

class _AttendanceDtrScreenState extends State<AttendanceDtrScreen> {
  String selectedRecord = 'All Records';
  final List<String> recordFilters = const ['All Records'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        selected: AppNavItem.attendanceDtr,
        onSelect: (item) {
          Navigator.pop(context);
          widget.onNavigate(item);
        },
        onSignOut: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign out tapped (UI only)')),
          );
        },
      ),
      appBar: AppBar(
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

          Row(
            children: const [
              Expanded(
                child: _MetricCard(
                  title: 'Tardiness',
                  value: '0m',
                  icon: Icons.access_time,
                  iconColor: Color(0xFFDD6B20),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'Undertime',
                  value: '0m',
                  icon: Icons.show_chart,
                  iconColor: Color(0xFF2F9E44),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: const [
              Expanded(
                child: _MetricCard(
                  title: 'Overtime',
                  value: '0m',
                  icon: Icons.watch_later_outlined,
                  iconColor: Color(0xFF0B3A6E),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'Absences',
                  value: '0',
                  icon: Icons.warning_amber_rounded,
                  iconColor: Color(0xFFE03131),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          const Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Workload\nCredits',
                  value: '0',
                  icon: Icons.event_note_outlined,
                  iconColor: Color(0xFF6F42C1),
                ),
              ),
              SizedBox(width: 10),
              Expanded(child: SizedBox()),
            ],
          ),

          const SizedBox(height: 18),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFFF1F1F1),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                        borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                        borderSide: const BorderSide(color: AppColors.primaryBlue),
                      ),
                    ),
                    items: recordFilters
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => selectedRecord = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFD8D8D8),
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
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