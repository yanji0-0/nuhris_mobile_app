import 'package:flutter/material.dart';
import '../navigation/app_nav.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';

class LeaveMonitoringScreen extends StatefulWidget {
  const LeaveMonitoringScreen({
    super.key,
    required this.onNavigate,
    required this.onSignOut,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;

  @override
  State<LeaveMonitoringScreen> createState() => _LeaveMonitoringScreenState();
}

class _LeaveMonitoringScreenState extends State<LeaveMonitoringScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.instance.getLeaveMonitoring();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        selected: AppNavItem.leaveMonitoring,
        onSelect: (item) {
          Navigator.pop(context);
          widget.onNavigate(item);
        },
        onSignOut: widget.onSignOut,
      ),
      appBar: AppBar(
        title: const Text('Leave Monitoring'),
        actions: [
          IconButton(
            onPressed: () => widget.onNavigate(AppNavItem.notifications),
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Failed to load leave data: ${snapshot.error}'));
          }

          final payload = snapshot.data ?? {};
          final balances = ((payload['balances'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList();
          final requests = ((payload['requests'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
            children: [
              const Text('View your leave balances and history. Leave data is managed by HR (read-only)', style: TextStyle(color: AppColors.mutedText, fontSize: 13, height: 1.3)),
              const SizedBox(height: 16),
              if (balances.isEmpty)
                const Center(
                  child: Text(
                    'No leave balance data available yet. HR\nwill upload this information.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF9AA0A6), fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                )
              else
                ...balances.map((b) => Card(
                      child: ListTile(
                        title: Text((b['leave_type'] ?? 'Leave').toString()),
                        subtitle: const Text('Remaining days'),
                        trailing: Text((b['remaining_days'] ?? 0).toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Leave History', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 30, color: Color(0xFF444444))),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
                        child: const Row(
                          children: [
                            _HeadCell('Type', flex: 2), _HeadCell('Start\nDate', flex: 2), _HeadCell('End\nDate', flex: 2),
                            _HeadCell('Days\nDeducted', flex: 3), _HeadCell('Status', flex: 2), _HeadCell('Cut Off', flex: 2), _HeadCell('Reason', flex: 2),
                          ],
                        ),
                      ),
                      if (requests.isEmpty) ...[
                        const SizedBox(height: 56),
                        const Center(child: Text('No leave history found', style: TextStyle(color: Color(0xFFB0B0B0), fontWeight: FontWeight.w600, fontSize: 15))),
                        const SizedBox(height: 56),
                      ] else ...[
                        const SizedBox(height: 10),
                        ...requests.take(20).map((r) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  _BodyCell((r['leave_type'] ?? '').toString(), flex: 2),
                                  _BodyCell(_date((r['start_date'] ?? '').toString()), flex: 2),
                                  _BodyCell(_date((r['end_date'] ?? '').toString()), flex: 2),
                                  _BodyCell((r['days_deducted'] ?? '').toString(), flex: 3),
                                  _BodyCell((r['status'] ?? '').toString(), flex: 2),
                                  _BodyCell(_date((r['cutoff_date'] ?? '').toString()), flex: 2),
                                  _BodyCell((r['reason'] ?? '').toString(), flex: 2),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _date(String value) => value.length >= 10 ? value.substring(0, 10) : value;
}

class _HeadCell extends StatelessWidget {
  const _HeadCell(this.text, {required this.flex});
  final String text;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF666666), height: 1.1)),
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
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10, color: Color(0xFF555555)),
      ),
    );
  }
}
