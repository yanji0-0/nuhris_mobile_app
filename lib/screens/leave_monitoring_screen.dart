import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/app_nav.dart';
import '../providers/api_client_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';

class LeaveMonitoringScreen extends ConsumerStatefulWidget {
  const LeaveMonitoringScreen({
    super.key,
    required this.onNavigate,
    required this.onSignOut,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;

  @override
  ConsumerState<LeaveMonitoringScreen> createState() =>
      _LeaveMonitoringScreenState();
}

class _LeaveMonitoringScreenState extends ConsumerState<LeaveMonitoringScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiClientProvider).getLeaveMonitoring();
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
        backgroundColor: const Color(0xFF0A2E86),
        foregroundColor: Colors.white,
        surfaceTintColor: const Color(0xFF0A2E86),
        elevation: 0,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text(
          'Leave Monitoring',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            onPressed: () => widget.onNavigate(AppNavItem.notifications),
            icon: const Icon(Icons.notifications_none_rounded),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load leave data: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }

          final payload = snapshot.data ?? {};
          final balances = ((payload['balances'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList()
            ..sort(_compareNewestFirst);
          final requests = ((payload['requests'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList()
            ..sort(_compareNewestFirst);
          final usageSummary = _buildLeaveUsageSummary(requests);
          final breakdown = _buildLeaveUsageBreakdown(requests);

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF6F8FC),
                  Color(0xFFF1F4FA),
                  Color(0xFFECEFF6),
                ],
              ),
            ),
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                children: [
                  const SizedBox(height: 6),
                  const Text(
                    'View your leave balances and history.\nLeave data is managed by HR (read-only).',
                    style: TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 16,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _LeaveUsageSummaryPanel(usageSummary: usageSummary),
                  const SizedBox(height: 18),
                  _BalancePanel(balances: balances),
                  const SizedBox(height: 18),
                  _LeaveUsageBreakdownPanel(breakdown: breakdown),
                  const SizedBox(height: 18),
                  const Text(
                    'Leave History',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (requests.isEmpty)
                    const _EmptyHistoryCard()
                  else
                    ...requests
                        .take(20)
                        .map((request) => _LeaveHistoryCard(request: request)),
                  const SizedBox(height: 28),
                  const _FooterNote(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

String _formatDate(String value) {
  if (value.isEmpty) {
    return '-';
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value.length >= 10 ? value.substring(0, 10) : value;
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

  return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
}

String _statusLabel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return 'Pending';
  }
  return normalized[0].toUpperCase() + normalized.substring(1).toLowerCase();
}

Color _statusBackground(String status) {
  switch (status.trim().toLowerCase()) {
    case 'approved':
      return const Color(0xFFE3F5E8);
    case 'rejected':
      return const Color(0xFFFBE4E2);
    case 'cancelled':
    case 'canceled':
      return const Color(0xFFE6E9F2);
    default:
      return const Color(0xFFFBE9D2);
  }
}

Color _statusForeground(String status) {
  switch (status.trim().toLowerCase()) {
    case 'approved':
      return const Color(0xFF2E8E46);
    case 'rejected':
      return const Color(0xFFD04A3B);
    case 'cancelled':
    case 'canceled':
      return const Color(0xFF51607A);
    default:
      return const Color(0xFFE38A1C);
  }
}

String _remainingDays(dynamic value) {
  if (value is int) {
    return value.toString();
  }

  if (value is num) {
    final asDouble = value.toDouble();
    return asDouble == asDouble.roundToDouble()
        ? asDouble.toInt().toString()
        : asDouble.toStringAsFixed(1);
  }

  return value?.toString() ?? '0';
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _normalizedLeaveType(String value) {
  return value.trim().toLowerCase();
}

String _prettyLeaveType(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return 'Leave';
  }

  return normalized
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

bool _isApprovedLeave(String status) {
  return status.trim().toLowerCase() == 'approved';
}

bool _isDeductibleLeaveType(String type) {
  final normalized = _normalizedLeaveType(type);
  return normalized.contains('vacation') ||
      normalized.contains('sick') ||
      normalized.contains('emergency');
}

Map<String, double> _buildLeaveUsageSummary(
  List<Map<String, dynamic>> requests,
) {
  final usage = <String, double>{
    'Vacation Used': 0,
    'Sick Used': 0,
    'Emergency Used': 0,
  };

  for (final request in requests) {
    if (!_isApprovedLeave((request['status'] ?? '').toString())) {
      continue;
    }

    final leaveType = _normalizedLeaveType(
      (request['leave_type'] ?? '').toString(),
    );
    final daysUsed = _toDouble(request['days_deducted']);

    if (leaveType.contains('vacation')) {
      usage['Vacation Used'] = usage['Vacation Used']! + daysUsed;
    } else if (leaveType.contains('sick')) {
      usage['Sick Used'] = usage['Sick Used']! + daysUsed;
    } else if (leaveType.contains('emergency')) {
      usage['Emergency Used'] = usage['Emergency Used']! + daysUsed;
    }
  }

  return usage;
}

Map<String, List<Map<String, dynamic>>> _buildLeaveUsageBreakdown(
  List<Map<String, dynamic>> requests,
) {
  final deductible = <String, Map<String, dynamic>>{};
  final trackedOnly = <String, Map<String, dynamic>>{};

  void accumulate(
    Map<String, Map<String, dynamic>> target,
    String label,
    double daysUsed,
  ) {
    final current = target[label];
    if (current == null) {
      target[label] = {'type': label, 'days_used': daysUsed, 'count': 1};
      return;
    }

    current['days_used'] = _toDouble(current['days_used']) + daysUsed;
    current['count'] = (current['count'] as int) + 1;
  }

  for (final request in requests) {
    if (!_isApprovedLeave((request['status'] ?? '').toString())) {
      continue;
    }

    final leaveTypeRaw = (request['leave_type'] ?? '').toString();
    final leaveType = _normalizedLeaveType(leaveTypeRaw);
    final label = _prettyLeaveType(leaveTypeRaw);
    final daysUsed = _toDouble(request['days_deducted']);

    if (daysUsed <= 0) {
      continue;
    }

    if (_isDeductibleLeaveType(leaveType)) {
      accumulate(deductible, label, daysUsed);
    } else {
      accumulate(trackedOnly, label, daysUsed);
    }
  }

  return {
    'deductible': deductible.values.toList(),
    'tracked_only': trackedOnly.values.toList(),
  };
}

String _formatDaysUsed(dynamic value) {
  final days = _toDouble(value);
  if (days == days.roundToDouble()) {
    return days.toInt().toString();
  }
  return days.toStringAsFixed(1);
}

DateTime _parseNewestDate(Map<String, dynamic> item) {
  final candidates = [
    item['updated_at']?.toString(),
    item['created_at']?.toString(),
  ];

  for (final candidate in candidates) {
    if (candidate == null || candidate.isEmpty) {
      continue;
    }

    final parsed = DateTime.tryParse(candidate);
    if (parsed != null) {
      return parsed;
    }
  }

  return DateTime.fromMillisecondsSinceEpoch(0);
}

int _compareNewestFirst(
  Map<String, dynamic> left,
  Map<String, dynamic> right,
) {
  return _parseNewestDate(right).compareTo(_parseNewestDate(left));
}

class _BalancePanel extends StatelessWidget {
  const _BalancePanel({required this.balances});

  final List<Map<String, dynamic>> balances;

  @override
  Widget build(BuildContext context) {
    if (balances.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8FE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFCAD7F7), width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF4D79F0), width: 2),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: Color(0xFF4D79F0),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No leave balance data available yet.\nHR will upload this information.',
                style: TextStyle(
                  color: Color(0xFF2A4EA8),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: balances.take(4).map((balance) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE6EAF3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F204070),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.beach_access_rounded,
                  color: Color(0xFF2852C7),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (balance['leave_type'] ?? 'Leave').toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_remainingDays(balance['remaining_days'])} remaining',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _LeaveUsageSummaryPanel extends StatelessWidget {
  const _LeaveUsageSummaryPanel({required this.usageSummary});

  final Map<String, double> usageSummary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Leave Usage Summary',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          childAspectRatio: 3.2,
          children: [
            _UsageSummaryCard(
              label: 'Vacation Used',
              value: _formatDaysUsed(usageSummary['Vacation Used']),
              foreground: const Color(0xFF1F8A46),
              background: const Color(0xFFE7F8EC),
              border: const Color(0xFFBFE6CD),
            ),
            _UsageSummaryCard(
              label: 'Sick Used',
              value: _formatDaysUsed(usageSummary['Sick Used']),
              foreground: const Color(0xFFB7791F),
              background: const Color(0xFFFFF4DD),
              border: const Color(0xFFF1D79B),
            ),
            _UsageSummaryCard(
              label: 'Emergency Used',
              value: _formatDaysUsed(usageSummary['Emergency Used']),
              foreground: const Color(0xFF7C3AED),
              background: const Color(0xFFF1E9FF),
              border: const Color(0xFFDCC8FF),
            ),
          ],
        ),
      ],
    );
  }
}

class _UsageSummaryCard extends StatelessWidget {
  const _UsageSummaryCard({
    required this.label,
    required this.value,
    required this.foreground,
    required this.background,
    required this.border,
  });

  final String label;
  final String value;
  final Color foreground;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveUsageBreakdownPanel extends StatelessWidget {
  const _LeaveUsageBreakdownPanel({required this.breakdown});

  final Map<String, List<Map<String, dynamic>>> breakdown;

  @override
  Widget build(BuildContext context) {
    final deductible = breakdown['deductible'] ?? const [];
    final trackedOnly = breakdown['tracked_only'] ?? const [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6EAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detailed Leave Usage',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          if (deductible.isEmpty && trackedOnly.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'No approved leave usage yet.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ),
          if (deductible.isNotEmpty) ...[
            const Text(
              'Leaves That Affect Balance',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF15803D),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            ...deductible.map(
              (usage) => _UsageBreakdownCard(
                type: (usage['type'] ?? 'Leave').toString(),
                daysUsed: _formatDaysUsed(usage['days_used']),
                count: (usage['count'] ?? 0) as int,
                background: const Color(0xFFF0FAF3),
                border: const Color(0xFFCFECD6),
                titleColor: const Color(0xFF14532D),
                valueColor: const Color(0xFF15803D),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (trackedOnly.isNotEmpty) ...[
            const Text(
              'Tracked Leaves (Balance Not Affected)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF475569),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            ...trackedOnly.map(
              (usage) => _UsageBreakdownCard(
                type: (usage['type'] ?? 'Leave').toString(),
                daysUsed: _formatDaysUsed(usage['days_used']),
                count: (usage['count'] ?? 0) as int,
                background: const Color(0xFFF8FAFC),
                border: const Color(0xFFE2E8F0),
                titleColor: const Color(0xFF0F172A),
                valueColor: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Note: These leaves are tracked for record-keeping but do not reduce your leave balance.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UsageBreakdownCard extends StatelessWidget {
  const _UsageBreakdownCard({
    required this.type,
    required this.daysUsed,
    required this.count,
    required this.background,
    required this.border,
    required this.titleColor,
    required this.valueColor,
  });

  final String type;
  final String daysUsed;
  final int count;
  final Color background;
  final Color border;
  final Color titleColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count request(s)',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            daysUsed,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveHistoryCard extends StatelessWidget {
  const _LeaveHistoryCard({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final status = (request['status'] ?? '').toString();
    final leaveType = (request['leave_type'] ?? 'Leave').toString();
    final startDate = (request['start_date'] ?? '').toString();
    final endDate = (request['end_date'] ?? '').toString();
    final cutoffDate = (request['cutoff_date'] ?? '').toString();
    final reason = (request['reason'] ?? leaveType).toString();
    final daysDeducted = (request['days_deducted'] ?? '').toString();
    final displayReason = reason
        .replaceFirst(
          RegExp(
            r'\s*[·•\-|]?\s*source\s+status\s*:\s*.*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x110E1B3D),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFF0F2F8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: Color(0xFF2852C7),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        leaveType,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StatusPill(
                      label: _statusLabel(status),
                      backgroundColor: _statusBackground(status),
                      foregroundColor: _statusForeground(status),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${_formatDate(startDate)} - ${_formatDate(endDate)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MetaItem(
                      icon: Icons.event_note_rounded,
                      label:
                          '${daysDeducted.isEmpty ? '-' : daysDeducted} Days',
                    ),
                    _MetaItem(
                      icon: Icons.schedule_rounded,
                      label: 'Cut-off: ${_formatDate(cutoffDate)}',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.35,
                    ),
                    children: [
                      const TextSpan(
                        text: 'Reason: ',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: displayReason.isEmpty ? leaveType : displayReason,
                      ),
                      const TextSpan(text: '   '),
                      const TextSpan(
                        text: 'Source status: ',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: status.isEmpty ? 'PENDING' : status.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x110E1B3D),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'No leave history found',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'All leave records are for your reference only.\nFor any concerns, please contact HR.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF8B95A7),
            fontSize: 14,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
