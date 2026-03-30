import 'package:flutter/material.dart';
import '../navigation/app_nav.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';

class LeaveMonitoringScreen extends StatelessWidget {
  const LeaveMonitoringScreen({super.key, required this.onNavigate});

  final ValueChanged<AppNavItem> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        selected: AppNavItem.leaveMonitoring,
        onSelect: (item) {
          Navigator.pop(context);
          onNavigate(item);
        },
        onSignOut: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign out tapped (UI only)')),
          );
        },
      ),
      appBar: AppBar(
        title: const Text('Leave Monitoring'),
        actions: [
          IconButton(
            onPressed: () => onNavigate(AppNavItem.notifications),
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
        children: [
          const Text(
            'View your leave balances and history. Leave data is managed by HR (read-only)',
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: 13,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 38),
          const Center(
            child: Text(
              'No leave balance data available yet. HR\nwill upload this information.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF9AA0A6),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 38),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Leave History',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 32,
                      color: Color(0xFF444444),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Header row (table-like)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Row(
                      children: [
                        _HeadCell('Type', flex: 2),
                        _HeadCell('Start\nDate', flex: 2),
                        _HeadCell('End\nDate', flex: 2),
                        _HeadCell('Days\nDeducted', flex: 3),
                        _HeadCell('Status', flex: 2),
                        _HeadCell('Cut Off', flex: 2),
                        _HeadCell('Reason', flex: 2),
                      ],
                    ),
                  ),

                  const SizedBox(height: 56),
                  const Center(
                    child: Text(
                      'No leave history found',
                      style: TextStyle(
                        color: Color(0xFFB0B0B0),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 56),
                ],
              ),
            ),
          ),
        ],
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
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF666666),
          height: 1.1,
        ),
      ),
    );
  }
}