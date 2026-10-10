import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/app_nav.dart';
import '../providers/app_refresh_provider.dart';
import '../providers/api_client_provider.dart';
import '../services/api_client.dart' show userMessageFor;
import '../utils/app_log.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/nuhris_app_bar.dart';

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
  int _lastRefreshToken = -1;

  @override
  void initState() {
    super.initState();
    _lastRefreshToken = ref.read(appRefreshProvider);
    _future = _loadLeaveMonitoring();
  }

  /// Last successfully loaded payload, kept on screen while the periodic
  /// background refresh re-fetches, so the page (and scroll) never resets.
  Map<String, dynamic>? _lastPayload;

  Future<Map<String, dynamic>> _loadLeaveMonitoring() async {
    final payload = await ref.read(apiClientProvider).getLeaveMonitoring();
    _lastPayload = payload;
    return payload;
  }

  void _syncRefreshToken(int refreshToken) {
    if (_lastRefreshToken == refreshToken) {
      return;
    }

    _lastRefreshToken = refreshToken;
    _future = _loadLeaveMonitoring();
  }

  @override
  Widget build(BuildContext context) {
    final refreshToken = ref.watch(appRefreshProvider);
    _syncRefreshToken(refreshToken);

    return Scaffold(
      drawer: AppDrawer(
        selected: AppNavItem.leaveMonitoring,
        onSelect: (item) {
          Navigator.pop(context);
          widget.onNavigate(item);
        },
      ),
      appBar: NuhrisAppBar(
        title: 'Leave Monitoring',
        currentItem: AppNavItem.leaveMonitoring,
        onNavigate: widget.onNavigate,
        onSignOut: widget.onSignOut,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          // Spinner/error only before the first successful load; a
          // background refresh keeps showing the previous data.
          final cached = snapshot.data ?? _lastPayload;
          if (cached == null &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (cached != null && snapshot.hasError) {
            appLog('Leave background refresh failed', snapshot.error.runtimeType);
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  userMessageFor(snapshot.error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }

          final payload = cached ?? const <String, dynamic>{};
          final balances = ((payload['balances'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList();
          // Already ordered like the web: latest start_date first.
          final requests = ((payload['requests'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList();
          final breakdown = _buildLeaveUsageBreakdown(
            requests,
            _currentEmploymentYearStart(payload['hire_date']),
          );
          final usageSummary = _buildLeaveUsageSummary(breakdown);
          final remainingBalances = _deductibleBalances(balances);

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
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                children: [
                  const Text(
                    'View your leave balances and history. Leave data is managed by HR (read-only).',
                    style: TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _Disclaimer(),
                  const SizedBox(height: 10),
                  _LeaveUsageSummaryPanel(usageSummary: usageSummary),
                  if (remainingBalances.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _RemainingBalanceSection(balances: remainingBalances),
                  ],
                  const SizedBox(height: 12),
                  _LeaveUsageBreakdownPanel(breakdown: breakdown),
                  const SizedBox(height: 12),
                  const Text(
                    'Leave History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (requests.isEmpty)
                    const _EmptyHistoryCard()
                  else
                    ...requests.map(
                      (request) => _LeaveHistoryCard(request: request),
                    ),
                  const SizedBox(height: 12),
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

/// Web Leave History start/end: `toDateString()` (Y-m-d).
String _historyDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return '${parsed.year.toString().padLeft(4, '0')}-'
      '${parsed.month.toString().padLeft(2, '0')}-'
      '${parsed.day.toString().padLeft(2, '0')}';
}

/// Web Leave History cut-off: `format('M d, Y') ?? '-'` (e.g. Aug 04, 2026).
String _historyCutoff(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return '-';
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

  return '${months[parsed.month - 1]} '
      '${parsed.day.toString().padLeft(2, '0')}, ${parsed.year}';
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

// ============================================================
// Port of the web `App\Services\LeaveBalanceService` +
// `Employee\PortalController::leave` calculations.
// ============================================================

/// Leave types that reduce the remaining balance (web DEDUCTIBLE_LEAVE_TYPES).
const _deductibleLeaveTypes = <String>[
  'Vacation Leave',
  'Sick Leave',
  'Emergency Leave',
];

/// Every leave type the web lists in "Detailed Leave Usage", in web order.
const _allLeaveTypes = <String>[
  'Vacation Leave',
  'Bereavement Leave',
  'Sick Leave',
  'Training Leave',
  'Official Business',
  'Work From Home',
  'Birthday Leave',
  'Emergency Leave',
  'Maternity Leave',
  'Solo Parent Leave',
  'Special Leave for Women',
  'Paternity Leave',
  'Study Leave With Pay',
  'Study Leave Without Pay',
  'Leave Without Pay',
  'Research Leave',
];

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

/// PHP `rtrim(rtrim(number_format($v, $decimals, '.', ''), '0'), '.')`.
String _formatDays(dynamic value, {int decimals = 2}) {
  final fixed = _toDouble(value).toStringAsFixed(decimals);
  if (!fixed.contains('.')) return fixed;
  return fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

DateTime? _dateOnly(dynamic value) {
  final parsed = DateTime.tryParse((value ?? '').toString());
  return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
}

/// Web `currentEmploymentYearStart()`: this year's hire anniversary, or last
/// year's if it is still in the future; Jan 1 when there is no hire date.
/// Evaluated in Asia/Manila (UTC+8), the web app's timezone.
DateTime _currentEmploymentYearStart(dynamic hireDateValue) {
  final manila = DateTime.now().toUtc().add(const Duration(hours: 8));
  final now = DateTime(
    manila.year,
    manila.month,
    manila.day,
    manila.hour,
    manila.minute,
    manila.second,
  );
  final hireDate = _dateOnly(hireDateValue);
  if (hireDate == null) {
    return DateTime(now.year, 1, 1);
  }

  final anniversary = DateTime(now.year, hireDate.month, hireDate.day);
  return anniversary.isAfter(now)
      ? DateTime(now.year - 1, hireDate.month, hireDate.day)
      : anniversary;
}

/// Web `getLeaveUsageBreakdown()`: approved requests only, matched by exact
/// leave type. Deductible types only count requests starting in the current
/// employment year; tracked types count all approved requests. `count` is
/// the number of approved requests of that type.
Map<String, List<Map<String, dynamic>>> _buildLeaveUsageBreakdown(
  List<Map<String, dynamic>> requests,
  DateTime employmentYearStart,
) {
  final approvedByType = <String, List<Map<String, dynamic>>>{};
  for (final request in requests) {
    if ((request['status'] ?? '').toString() != 'approved') continue;
    final type = (request['leave_type'] ?? '').toString();
    approvedByType.putIfAbsent(type, () => []).add(request);
  }

  final deductible = <Map<String, dynamic>>[];
  final trackedOnly = <Map<String, dynamic>>[];

  for (final type in _allLeaveTypes) {
    final approved = approvedByType[type] ?? const [];
    final isDeductible = _deductibleLeaveTypes.contains(type);
    final counted = isDeductible
        ? approved.where((request) {
            final start = _dateOnly(request['start_date']);
            return start != null && !start.isBefore(employmentYearStart);
          })
        : approved;
    final daysUsed = counted.fold<double>(
      0,
      (sum, request) => sum + _toDouble(request['days_deducted']),
    );

    final entry = {'type': type, 'days_used': daysUsed, 'count': approved.length};
    (isDeductible ? deductible : trackedOnly).add(entry);
  }

  return {'deductible': deductible, 'tracked_only': trackedOnly};
}

/// Web "Leave Usage Summary": derived from the deductible breakdown.
Map<String, double> _buildLeaveUsageSummary(
  Map<String, List<Map<String, dynamic>>> breakdown,
) {
  final usage = <String, double>{
    'Vacation Used': 0,
    'Sick Used': 0,
    'Emergency Used': 0,
  };

  for (final entry in breakdown['deductible'] ?? const []) {
    final type = (entry['type'] ?? '').toString().toLowerCase();
    final days = _toDouble(entry['days_used']);
    if (type.contains('vacation')) {
      usage['Vacation Used'] = usage['Vacation Used']! + days;
    } else if (type.contains('sick')) {
      usage['Sick Used'] = usage['Sick Used']! + days;
    } else if (type.contains('emergency')) {
      usage['Emergency Used'] = usage['Emergency Used']! + days;
    }
  }

  return usage;
}

/// Web `getDeductibleLeaveBalances()`: stored `leave_balances` rows for the
/// deductible types, ordered by leave type.
List<Map<String, dynamic>> _deductibleBalances(
  List<Map<String, dynamic>> balances,
) {
  return balances
      .where(
        (row) => _deductibleLeaveTypes.contains(
          (row['leave_type'] ?? '').toString(),
        ),
      )
      .toList()
    ..sort(
      (left, right) => (left['leave_type'] ?? '').toString().compareTo(
        (right['leave_type'] ?? '').toString(),
      ),
    );
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
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _UsageSummaryCard(
                label: 'Vacation Used',
                value: _formatDays(usageSummary['Vacation Used'], decimals: 1),
                foreground: const Color(0xFF1F8A46),
                background: const Color(0xFFE7F8EC),
                border: const Color(0xFFBFE6CD),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _UsageSummaryCard(
                label: 'Sick Used',
                value: _formatDays(usageSummary['Sick Used'], decimals: 1),
                foreground: const Color(0xFFB7791F),
                background: const Color(0xFFFFF4DD),
                border: const Color(0xFFF1D79B),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _UsageSummaryCard(
                label: 'Emergency Used',
                value: _formatDays(usageSummary['Emergency Used'], decimals: 1),
                foreground: const Color(0xFF7C3AED),
                background: const Color(0xFFF1E9FF),
                border: const Color(0xFFDCC8FF),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _RemainingBalanceSection extends StatelessWidget {
  const _RemainingBalanceSection({required this.balances});

  /// Stored `leave_balances` rows (deductible types, ordered by type).
  final List<Map<String, dynamic>> balances;

  @override
  Widget build(BuildContext context) {
    const accents = [Color(0xFF2B57D1), Color(0xFF1D4ED8), Color(0xFF1E40AF)];
    final cards = [
      for (var i = 0; i < balances.length; i++)
        _RemainingBalanceCard(
          label: (balances[i]['leave_type'] ?? '').toString(),
          value: _formatDays(balances[i]['remaining_days']),
          accent: accents[i % accents.length],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Remaining Leave Balance',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 620 ? 3 : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: columns == 3 ? 1.18 : 2.7,
              children: cards,
            );
          },
        ),
      ],
    );
  }
}

class _RemainingBalanceCard extends StatelessWidget {
  const _RemainingBalanceCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D1F2937),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: accent.withValues(alpha: 0.88),
              fontWeight: FontWeight.w500,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: const Color(0xFF1E2B6C),
              fontWeight: FontWeight.w800,
              fontSize: 32,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Remaining days',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6EAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detailed Leave Usage',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          if (deductible.isNotEmpty) ...[
            const Text(
              'LEAVES THAT AFFECT BALANCE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: Color(0xFF15803D),
              ),
            ),
            const SizedBox(height: 6),
            // Web: shown with usage when count > 0 or days_used > 0.
            ...deductible.map(
              (usage) => _UsageBreakdownCard(
                type: (usage['type'] ?? 'Leave').toString(),
                daysUsed: _formatDays(usage['days_used']),
                count: (usage['count'] ?? 0) as int,
                hasUsage:
                    ((usage['count'] ?? 0) as int) > 0 ||
                    _toDouble(usage['days_used']) > 0,
                background: const Color(0xFFF0FAF3),
                border: const Color(0xFFCFECD6),
                titleColor: const Color(0xFF14532D),
                valueColor: const Color(0xFF15803D),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (trackedOnly.isNotEmpty) ...[
            const Text(
              'TRACKED LEAVES (BALANCE NOT AFFECTED)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            // Web: shown with usage only when count > 0.
            ...trackedOnly.map(
              (usage) => _UsageBreakdownCard(
                type: (usage['type'] ?? 'Leave').toString(),
                daysUsed: _formatDays(usage['days_used']),
                count: (usage['count'] ?? 0) as int,
                hasUsage: ((usage['count'] ?? 0) as int) > 0,
                background: const Color(0xFFF8FAFC),
                border: const Color(0xFFE2E8F0),
                titleColor: const Color(0xFF0F172A),
                valueColor: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Note: These leaves are tracked for record-keeping but do not '
              'reduce your leave balance.',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Color(0xFF64748B),
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
    required this.hasUsage,
    required this.background,
    required this.border,
    required this.titleColor,
    required this.valueColor,
  });

  final String type;
  final String daysUsed;
  final int count;
  final bool hasUsage;
  final Color background;
  final Color border;
  final Color titleColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    // Web dims unused types and shows "0 / No usage".
    return Opacity(
      opacity: hasUsage ? 1 : 0.5,
      child: _buildCard(),
    );
  }

  Widget _buildCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
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
                    fontSize: 13,
                  ),
                ),
                Text(
                  hasUsage ? '$count request(s)' : 'No usage',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            hasUsage ? daysUsed : '0',
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w800,
              fontSize: 18,
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
    // Shown exactly as the web table (including "· Source status: …").
    final reason = (request['reason'] ?? '').toString().trim();
    final daysDeducted = request['days_deducted'] == null
        ? ''
        : _formatDays(request['days_deducted']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6EAF3)),
      ),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(
                label: _statusLabel(status),
                backgroundColor: _statusBackground(status),
                foregroundColor: _statusForeground(status),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_historyDate(startDate)} – ${_historyDate(endDate)}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _MetaItem(
                icon: Icons.event_note_rounded,
                label: '${daysDeducted.isEmpty ? '-' : daysDeducted} days',
              ),
              _MetaItem(
                icon: Icons.schedule_rounded,
                label: 'Cut-off: ${_historyCutoff(cutoffDate)}',
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            // `leave_requests.reason`, exactly as the web Reason column.
            Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  height: 1.3,
                ),
                children: [
                  const TextSpan(
                    text: 'Reason: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  TextSpan(text: reason),
                ],
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          fontSize: 11,
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
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6EAF3)),
      ),
      child: const Center(
        child: Text(
          'No leave history found',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// Same wording as the current web Leave Monitoring disclaimer.
class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Text.rich(
        TextSpan(
          style: TextStyle(
            color: Color(0xFF92400E),
            fontSize: 12.5,
            height: 1.35,
          ),
          children: [
            TextSpan(
              text: 'Disclaimer: ',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text:
                  'Leave counts shown here are converted to days, not hours. '
                  'Please view your NUIS account for the most accurate leave '
                  'hours.',
            ),
          ],
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
      child: Text(
        'For concerns, contact HR.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF8B95A7),
          fontSize: 12,
        ),
      ),
    );
  }
}
