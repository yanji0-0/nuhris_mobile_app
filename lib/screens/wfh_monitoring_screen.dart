import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../navigation/app_nav.dart';
import '../services/api_client.dart';
import '../widgets/app_drawer.dart';
import '../theme/app_theme.dart';
import 'wfh_monitoring_upload.dart';

class WFHMonitoringScreen extends StatefulWidget {
  const WFHMonitoringScreen({
    super.key,
    required this.onNavigate,
    required this.onSignOut,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;

  @override
  State<WFHMonitoringScreen> createState() => _WFHMonitoringScreenState();
}

class _WFHMonitoringScreenState extends State<WFHMonitoringScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _submissions = [];

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    try {
      final data = await ApiClient.instance.getWfhMonitoringSubmissions();
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

  Future<void> _viewFile(String? filePath) async {
    final stored = (filePath ?? '').toString();
    if (stored.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file attached to this submission.')),
      );
      return;
    }

    try {
      final url = await ApiClient.instance.getCredentialFileUrl(stored);
      if (url == null || url.isEmpty) {
        if (!context.mounted) return;

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('File Not Found'),
            content: const Text(
              'The file for this submission could not be found.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      final lower = url.toLowerCase();
      if (lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.contains('image/')) {
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (_) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: InteractiveViewer(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) =>
                          Center(child: Text('Unable to load image:\n$err')),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(
                          Uri.parse(url),
                          mode: LaunchMode.externalApplication,
                        );
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open in Browser'),
                  ),
                ),
              ],
            ),
          ),
        );
        return;
      }

      // For PDFs and documents, open directly
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open file. No suitable app found.'),
          ),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open file: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      drawer: AppDrawer(
        selected: AppNavItem.wfhMonitoring,
        onSelect: (item) {
          Navigator.pop(context);
          widget.onNavigate(item);
        },
        onSignOut: widget.onSignOut,
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1B66),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('WFH Monitoring'),
        actions: [
          IconButton(
            onPressed: () => widget.onNavigate(AppNavItem.notifications),
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifications',
          ),
        ],
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
                      Flexible(
                        child: _SummaryCard(
                          'TOTAL',
                          _totalCount.toString(),
                          const Color(0xFFF3F4F6),
                        ),
                      ),
                      Flexible(
                        child: _SummaryCard(
                          'PENDING',
                          _pendingCount.toString(),
                          const Color(0xFFFEF3C7),
                          labelColor: const Color(0xFFB45309),
                        ),
                      ),
                      Flexible(
                        child: _SummaryCard(
                          'APPROVED',
                          _approvedCount.toString(),
                          const Color(0xFFD1FAE5),
                          labelColor: const Color(0xFF065F46),
                        ),
                      ),
                      Flexible(
                        child: _SummaryCard(
                          'DECLINED',
                          _declinedCount.toString(),
                          const Color(0xFFECF0F1),
                          labelColor: const Color(0xFF4B5563),
                        ),
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
                                          _viewFile(submission['file_path']),
                                      child: const Text(
                                        'View file',
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
                                            _viewFile(submission['file_path']),
                                        child: const Text('View file'),
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
