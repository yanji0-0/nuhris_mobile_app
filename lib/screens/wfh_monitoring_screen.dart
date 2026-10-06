import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../navigation/app_nav.dart';
import '../providers/app_refresh_provider.dart';
import '../providers/api_client_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/nuhris_app_bar.dart';
import '../theme/app_theme.dart';
import 'wfh_monitoring_upload.dart';

class WFHMonitoringScreen extends ConsumerStatefulWidget {
  const WFHMonitoringScreen({
    super.key,
    required this.onNavigate,
    required this.onSignOut,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;

  @override
  ConsumerState<WFHMonitoringScreen> createState() =>
      _WFHMonitoringScreenState();
}

class _WFHMonitoringScreenState extends ConsumerState<WFHMonitoringScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _submissions = [];
  int _lastRefreshToken = -1;

  @override
  void initState() {
    super.initState();
    _lastRefreshToken = ref.read(appRefreshProvider);
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.getWfhMonitoringSubmissions();
      if (!mounted) return;
      setState(() {
        _submissions = data;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  void _syncRefreshToken(int refreshToken) {
    if (_lastRefreshToken == refreshToken) {
      return;
    }

    _lastRefreshToken = refreshToken;
    _isLoading = true;
    _error = null;
    _loadSubmissions();
  }

  int get _totalCount => _submissions.length;

  int get _pendingCount => _submissions
      .where((s) => _normalizeStatus(s['status']).toLowerCase() == 'pending')
      .length;

  int get _approvedCount => _submissions
      .where((s) => _normalizeStatus(s['status']).toLowerCase() == 'approved')
      .length;

  int get _declinedCount => _submissions
      .where(
        (s) =>
            _normalizeStatus(s['status']).toLowerCase() == 'declined' ||
            _normalizeStatus(s['status']).toLowerCase() == 'rejected',
      )
      .length;

  String _normalizeStatus(dynamic status) {
    final str = (status ?? '').toString().trim();
    return str.isEmpty ? 'pending' : str;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '--';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--';
    final parts = timeStr.split(':');
    if (parts.length < 2) return timeStr;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $ampm';
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '--';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
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
    final month = months[date.month - 1];
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    return '$month ${date.day}, ${date.year} ${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $ampm';
  }

  Color _statusColor(String status) {
    final normalized = _normalizeStatus(status).toLowerCase();
    if (normalized == 'approved') return const Color(0xFF10B981);
    if (normalized == 'pending') return const Color(0xFFF59E0B);
    if (normalized == 'declined' || normalized == 'rejected')
      return const Color(0xFFEF4444);
    return const Color(0xFF6B7280);
  }

  /// Mirrors the web WFH page: "View link" opens the submission's
  /// `monitoring_link` in a new browser tab / external browser. It is a web
  /// link, not a stored file, so it never goes through the PDF viewer.
  Future<void> _viewLink(dynamic monitoringLink) async {
    final messenger = ScaffoldMessenger.of(context);
    final link = (monitoringLink ?? '').toString().trim();
    if (link.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No monitoring link attached to this submission.'),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(link);
    final isWebLink =
        uri != null && (uri.isScheme('http') || uri.isScheme('https'));
    var opened = false;
    if (isWebLink) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (error) {
        debugPrint('WFH monitoring link failed to open: $error');
      }
    }

    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to open the monitoring link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final refreshToken = ref.watch(appRefreshProvider);
    _syncRefreshToken(refreshToken);

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      drawer: AppDrawer(
        selected: AppNavItem.wfhMonitoring,
        onSelect: (item) {
          Navigator.pop(context);
          widget.onNavigate(item);
        },
      ),
      appBar: NuhrisAppBar(
        title: 'WFH Monitoring',
        currentItem: AppNavItem.wfhMonitoring,
        onNavigate: widget.onNavigate,
        onSignOut: widget.onSignOut,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load submissions: $_error',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
              children: [
                const Text(
                  'Upload your Work Output Monitoring Sheet for a WFH day. Once HR approves it, the approved date is written to your attendance record.',
                  style: TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                if (!isMobile)
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WFHMonitoringUploadScreen(),
                          ),
                        ).then((_) => _loadSubmissions());
                      },
                      child: const Text(
                        'Upload New',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2B2F36),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                if (!isMobile)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _SummaryCard(
                        'TOTAL',
                        _totalCount.toString(),
                        const Color(0xFFF3F4F6),
                      ),
                      _SummaryCard(
                        'PENDING',
                        _pendingCount.toString(),
                        const Color(0xFFFEF3C7),
                        labelColor: const Color(0xFFB45309),
                      ),
                      _SummaryCard(
                        'APPROVED',
                        _approvedCount.toString(),
                        const Color(0xFFD1FAE5),
                        labelColor: const Color(0xFF065F46),
                      ),
                      _SummaryCard(
                        'DECLINED',
                        _declinedCount.toString(),
                        const Color(0xFFECF0F1),
                        labelColor: const Color(0xFF4B5563),
                      ),
                    ],
                  ),
                if (isMobile)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SummaryCard(
                        'TOTAL',
                        _totalCount.toString(),
                        const Color(0xFFF3F4F6),
                      ),
                      _SummaryCard(
                        'PENDING',
                        _pendingCount.toString(),
                        const Color(0xFFFEF3C7),
                        labelColor: const Color(0xFFB45309),
                      ),
                      _SummaryCard(
                        'APPROVED',
                        _approvedCount.toString(),
                        const Color(0xFFD1FAE5),
                        labelColor: const Color(0xFF065F46),
                      ),
                      _SummaryCard(
                        'DECLINED',
                        _declinedCount.toString(),
                        const Color(0xFFECF0F1),
                        labelColor: const Color(0xFF4B5563),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WFH Monitoring Submissions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4B4B4B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Approved entries will create or update your attendance record for the selected WFH date.',
                          style: TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_submissions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text(
                                'No WFH monitoring sheets uploaded yet.\nUpload your first Work Output Monitoring Sheet to start the review flow.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.mutedText,
                                ),
                              ),
                            ),
                          )
                        else if (isMobile)
                          ..._submissions.map((submission) {
                            final date = _formatDate(submission['wfh_date']);
                            final timeIn = _formatTime(submission['time_in']);
                            final timeOut = _formatTime(submission['time_out']);
                            final status = _normalizeStatus(
                              submission['status'],
                            );
                            final reviewed = _formatDateTime(
                              submission['reviewed_at'] ??
                                  submission['submitted_at'],
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Date: $date',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusColor(
                                            status,
                                          ).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: _statusColor(status),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Time In: $timeIn',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                  Text(
                                    'Time Out: $timeOut',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                  Text(
                                    'Reviewed: $reviewed',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () =>
                                          _viewLink(submission['monitoring_link']),
                                      child: const Text(
                                        'View link',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('DATE')),
                                DataColumn(label: Text('TIME IN')),
                                DataColumn(label: Text('TIME OUT')),
                                DataColumn(label: Text('STATUS')),
                                DataColumn(label: Text('REVIEWED')),
                                DataColumn(label: Text('FILE')),
                              ],
                              rows: _submissions.map((submission) {
                                final date = _formatDate(
                                  submission['wfh_date'],
                                );
                                final timeIn = _formatTime(
                                  submission['time_in'],
                                );
                                final timeOut = _formatTime(
                                  submission['time_out'],
                                );
                                final status = _normalizeStatus(
                                  submission['status'],
                                );
                                final reviewed = _formatDateTime(
                                  submission['reviewed_at'] ??
                                      submission['submitted_at'],
                                );

                                return DataRow(
                                  cells: [
                                    DataCell(Text(date)),
                                    DataCell(Text(timeIn)),
                                    DataCell(Text(timeOut)),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusColor(
                                            status,
                                          ).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: _statusColor(status),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(reviewed)),
                                    DataCell(
                                      TextButton(
                                        onPressed: () =>
                                            _viewLink(submission['monitoring_link']),
                                        child: const Text('View link'),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(
    this.label,
    this.value,
    this.backgroundColor, {
    this.labelColor,
  });

  final String label;
  final String value;
  final Color backgroundColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      constraints: const BoxConstraints(minWidth: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: labelColor ?? const Color(0xFF6B7280),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
}
