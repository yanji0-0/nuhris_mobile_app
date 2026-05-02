import 'package:flutter/material.dart';
import 'file_viewer_screen.dart';
// import 'package:flutter/services.dart'; // removed - unnecessary import
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/app_nav.dart';
import '../providers/api_client_provider.dart';
import '../widgets/app_drawer.dart';
import 'credential_upload_screen.dart';

class CredentialsScreen extends ConsumerStatefulWidget {
  const CredentialsScreen({
    super.key,
    required this.onNavigate,
    required this.onSignOut,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;

  @override
  ConsumerState<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends ConsumerState<CredentialsScreen> {
  int selectedTab = 0;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _credentials = const [];

  final List<String> tabs = const [
    'All',
    'Resume',
    'PRC License',
    'Seminars',
    'Degrees',
  ];

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.getEmployeeCredentials();
      if (!mounted) {
        return;
      }
      // Sort newest uploaded first (prefer created_at, fallback to updated_at)
      data.sort((a, b) {
        DateTime parseDate(Map<String, dynamic> item) {
          final created = (item['created_at'] ?? '').toString();
          final updated = (item['updated_at'] ?? '').toString();
          return DateTime.tryParse(created) ??
              DateTime.tryParse(updated) ??
              DateTime.fromMillisecondsSinceEpoch(0);
        }

        final da = parseDate(a.cast<String, dynamic>());
        final db = parseDate(b.cast<String, dynamic>());
        return db.compareTo(da);
      });

      setState(() {
        _credentials = data;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredCredentials {
    final selectedType = _tabTypeForIndex(selectedTab);
    if (selectedType == null) {
      return _credentials;
    }

    return _credentials.where((item) {
      final rawType = (item['credential_type'] ?? '').toString();
      return _normalizeCredentialType(rawType) == selectedType;
    }).toList();
  }

  String? _tabTypeForIndex(int index) {
    switch (index) {
      case 1:
        return 'resume';
      case 2:
        return 'prc';
      case 3:
        return 'seminars';
      case 4:
        return 'degrees';
      default:
        return null;
    }
  }

  int _tabCountAt(int index) {
    final type = _tabTypeForIndex(index);
    if (type == null) {
      return _credentials.length;
    }

    return _credentials.where((item) {
      final rawType = (item['credential_type'] ?? '').toString();
      return _normalizeCredentialType(rawType) == type;
    }).length;
  }

  String _normalizeCredentialType(String rawType) {
    final value = rawType.trim().toLowerCase();
    if (value.contains('resume')) {
      return 'resume';
    }
    if (value == 'prc' || value.contains('prc license')) {
      return 'prc';
    }
    if (value.contains('seminar') || value.contains('training')) {
      return 'seminars';
    }
    if (value.contains('degree') || value.contains('academic')) {
      return 'degrees';
    }
    return value;
  }

  String _displayTypeLabel(String rawType) {
    switch (_normalizeCredentialType(rawType)) {
      case 'resume':
        return 'Resume';
      case 'prc':
        return 'PRC License';
      case 'seminars':
        return 'Seminars';
      case 'degrees':
        return 'Degrees';
      default:
        return rawType.trim().isEmpty ? 'Credential' : rawType;
    }
  }

  _CredentialTypeStyle _credentialTypeStyle(String rawType) {
    switch (_normalizeCredentialType(rawType)) {
      case 'resume':
        return const _CredentialTypeStyle(
          icon: Icons.badge_outlined,
          background: Color(0xFFE7EEFB),
          foreground: Color(0xFF2C5FC7),
        );
      case 'prc':
        return const _CredentialTypeStyle(
          icon: Icons.verified_outlined,
          background: Color(0xFFF1E8FD),
          foreground: Color(0xFF8646DD),
        );
      case 'seminars':
        return const _CredentialTypeStyle(
          icon: Icons.groups_2_outlined,
          background: Color(0xFFE7F8EC),
          foreground: Color(0xFF2F9A58),
        );
      case 'degrees':
        return const _CredentialTypeStyle(
          icon: Icons.school_outlined,
          background: Color(0xFFFFF3D9),
          foreground: Color(0xFFC58B12),
        );
      default:
        return const _CredentialTypeStyle(
          icon: Icons.description_outlined,
          background: Color(0xFFEFF2F7),
          foreground: Color(0xFF65748B),
        );
    }
  }

  _StatusBadgeStyle _statusBadgeStyle(String rawStatus) {
    final status = rawStatus.trim().toLowerCase();

    if (status == 'pending') {
      return const _StatusBadgeStyle(
        label: 'Pending',
        background: Color(0xFFFCECC2),
        foreground: Color(0xFF9A6A00),
      );
    }

    if (status == 'verified' ||
        status == 'approved' ||
        status == 'active' ||
        status == 'compliant' ||
        status == 'valid') {
      return const _StatusBadgeStyle(
        label: 'Approved',
        background: Color(0xFFDDF5E3),
        foreground: Color(0xFF2E8B57),
      );
    }

    if (status == 'expired' || status == 'rejected' || status == 'invalid') {
      return const _StatusBadgeStyle(
        label: 'Rejected',
        background: Color(0xFFFADADD),
        foreground: Color(0xFFB3261E),
      );
    }

    return _StatusBadgeStyle(
      label: rawStatus.trim().isEmpty ? 'Pending' : rawStatus,
      background: const Color(0xFFE8EBF0),
      foreground: const Color(0xFF4B5563),
    );
  }

  DateTime? _parseDate(Object? value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  DateTime? _effectiveExpiresAt(Map<String, dynamic> item) {
    final rawType = (item['credential_type'] ?? '').toString();
    final normalizedType = _normalizeCredentialType(rawType);
    if (normalizedType != 'resume' && normalizedType != 'prc') return null;

    final expiresAt = _parseDate(item['expires_at']);
    if (normalizedType == 'prc') return expiresAt;

    final createdAt = _parseDate(item['created_at']);
    if (expiresAt == null) return createdAt?.add(const Duration(days: 365));

    if (createdAt != null &&
        expiresAt.year == createdAt.year &&
        expiresAt.month == createdAt.month &&
        expiresAt.day == createdAt.day) {
      return createdAt.add(const Duration(days: 365));
    }

    return expiresAt;
  }

  _ExpiryBadgeStyle? _expiryBadgeStyle(Map<String, dynamic> item) {
    final rawType = (item['credential_type'] ?? '').toString();
    final normalizedType = _normalizeCredentialType(rawType);
    final thresholdDays = switch (normalizedType) {
      'resume' => 30,
      'prc' => 90,
      _ => null,
    };
    if (thresholdDays == null) return null;

    final expiresAt = _effectiveExpiresAt(item);
    if (expiresAt == null) return null;

    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final expiryDate = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);

    if (expiryDate.isBefore(startOfToday)) {
      return const _ExpiryBadgeStyle(
        label: 'Expired',
        background: Color(0xFFFADADD),
        foreground: Color(0xFFB3261E),
      );
    }

    final warningEnd = startOfToday.add(Duration(days: thresholdDays));
    if (!expiryDate.isAfter(warningEnd)) {
      return const _ExpiryBadgeStyle(
        label: 'Expiring Soon',
        background: Color(0xFFFCECC2),
        foreground: Color(0xFF9A6A00),
      );
    }

    return null;
  }

  String _formatDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'No date';
    }

    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) {
      return trimmed.length >= 10 ? trimmed.substring(0, 10) : trimmed;
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

  String _credentialDate(Map<String, dynamic> item) {
    final createdAt = (item['created_at'] ?? '').toString();
    if (createdAt.isNotEmpty) {
      return _formatDate(createdAt);
    }

    final updatedAt = (item['updated_at'] ?? '').toString();
    if (updatedAt.isNotEmpty) {
      return _formatDate(updatedAt);
    }

    final expiresAt = (item['expires_at'] ?? '').toString();
    if (expiresAt.isNotEmpty) {
      return _formatDate(expiresAt);
    }

    return 'No date';
  }

  String _optionalDate(Object? value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return '-';

    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;

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

  String _effectiveCredentialExpiration(Map<String, dynamic> item) {
    final rawType = (item['credential_type'] ?? '').toString();
    final normalized = _normalizeCredentialType(rawType);
    final expiresAt = (item['expires_at'] ?? '').toString().trim();
    final createdAt = (item['created_at'] ?? '').toString().trim();

    if (normalized != 'resume' && normalized != 'prc') return '-';

    if (expiresAt.isEmpty) {
      if (normalized == 'resume' && createdAt.isNotEmpty) {
        final created = DateTime.tryParse(createdAt);
        if (created != null) {
          final effective = created.add(const Duration(days: 365));
          return _optionalDate(effective.toIso8601String());
        }
      }
      return '-';
    }

    final parsedExpires = DateTime.tryParse(expiresAt);
    final parsedCreated = DateTime.tryParse(createdAt);
    if (normalized == 'resume' &&
        parsedExpires != null &&
        parsedCreated != null &&
        parsedExpires.year == parsedCreated.year &&
        parsedExpires.month == parsedCreated.month &&
        parsedExpires.day == parsedCreated.day) {
      final effective = parsedCreated.add(const Duration(days: 365));
      return _optionalDate(effective.toIso8601String());
    }

    return _optionalDate(expiresAt);
  }

  String _lastUpdateLabel(Map<String, dynamic> item) {
    return _optionalDate(item['updated_at']);
  }

  String _hrNoteLabel(Map<String, dynamic> item) {
    final note = (item['review_notes'] ?? '').toString().trim();
    return note.isEmpty ? '-' : note;
  }

  String _fileExtensionFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final path = (uri?.path ?? url).toLowerCase();
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    return path.substring(dot + 1);
  }

  void _openUploadScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CredentialUploadScreen(
          onNavigate: widget.onNavigate,
          onSubmitted: _loadCredentials,
        ),
      ),
    );
  }

  Future<void> _viewFile(Map<String, dynamic> item) async {
    final stored = (item['file_path'] ?? '').toString();
    if (stored.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file attached to this credential.')),
      );
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      final url = await api.getCredentialFileUrl(stored);
      if (url == null || url.isEmpty) {
        if (!context.mounted) return;

        // Show debug info about what was tried
        final debugMsg =
            'File not found. Stored path: $stored\n'
            'Tried all known credential storage buckets. '
            'The bucket may not exist or the file may have been deleted.';

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('File Not Found'),
            content: Text(debugMsg),
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
      final ext = _fileExtensionFromUrl(url);
      final isImage =
          ext == 'png' ||
          ext == 'jpg' ||
          ext == 'jpeg' ||
          ext == 'gif' ||
          ext == 'webp';
      final isPdf = ext == 'pdf';

      if (isImage) {
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
                      try {
                        await launchUrl(Uri.parse(url),
                            mode: LaunchMode.externalApplication);
                        if (context.mounted) Navigator.pop(context);
                      } catch (_) {
                        if (!context.mounted) return;
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Open File'),
                            content: SelectableText('Unable to open file directly. URL:\n$url'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
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

      if (isPdf) {
        final title = (item['title'] ?? 'Credential').toString();
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FileViewerScreen(url: url, title: title),
          ),
        );
        return;
      }

      // Prefer in-app viewer for HTTP(S) URLs
      if (url.startsWith('http://') || url.startsWith('https://')) {
        final title = (item['title'] ?? 'Credential').toString();
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FileViewerScreen(url: url, title: title),
          ),
        );
        return;
      }

      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (e) {
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Open File'),
            content: SelectableText('Unable to open file directly. URL:\n$url'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
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

  Future<void> _confirmDeleteCredential(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete credential'),
        content: const Text(
          'Are you sure you want to delete this credential? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final id = item['id'];
      final filePath = (item['file_path'] ?? '').toString();
      final api = ref.read(apiClientProvider);
      await api.deleteEmployeeCredential(
        id: id,
        filePath: filePath.isEmpty ? null : filePath,
      );

      // Reload from server and verify row is actually gone to avoid false success.
      await _loadCredentials();
      final stillExists = _credentials.any((c) => c['id'] == id);
      if (stillExists) {
        throw Exception(
          'Delete did not apply on server. Your account may not have DELETE permission for this credential.',
        );
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Credential deleted.')));
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete credential: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        selected: AppNavItem.credentials,
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
          'Credentials',
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6F8FC), Color(0xFFF1F4FA), Color(0xFFECEFF6)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Failed to load credentials: $_error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7EEFB),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.badge_outlined,
                            color: Color(0xFF2C5FC7),
                            size: 34,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Upload and manage your credentials.\nHR will review and verify submissions.',
                              style: TextStyle(
                                color: Color(0xFF4B556A),
                                fontSize: 16,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _openUploadScreen,
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
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE3E8F2)),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(tabs.length, (index) {
                            final selected = index == selectedTab;
                            return Padding(
                              padding: EdgeInsets.only(
                                right: index == tabs.length - 1 ? 0 : 6,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => setState(() => selectedTab = index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFFEAF0FF)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFFB8C9F4)
                                          : const Color(0xFFE3E8F2),
                                    ),
                                  ),
                                  child: Text(
                                    '${tabs[index]} (${_tabCountAt(index)})',
                                    style: TextStyle(
                                      color: selected
                                          ? const Color(0xFF1E4FB4)
                                          : const Color(0xFF66748A),
                                      fontSize: 13,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_filteredCredentials.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 30,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE6ECF6)),
                        ),
                        child: const Text(
                          'No credentials found.\nUpload your first credential above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF92A0B5),
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      )
                    else
                      ..._filteredCredentials.map((item) {
                        final title = (item['title'] ?? 'Credential')
                            .toString();
                        final rawType = (item['credential_type'] ?? '')
                            .toString();
                        final typeStyle = _credentialTypeStyle(rawType);
                        final badgeStyle = _statusBadgeStyle(
                          (item['status'] ?? 'pending').toString(),
                        );
                        final expiryBadgeStyle = _expiryBadgeStyle(item);
                        final expirationDate = _effectiveCredentialExpiration(
                          item,
                        );
                        final lastUpdate = _lastUpdateLabel(item);
                        final hrNote = _hrNoteLabel(item);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE6ECF6)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x080B1E43),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: typeStyle.background,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      typeStyle.icon,
                                      color: typeStyle.foreground,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF111827),
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _displayTypeLabel(rawType),
                                          style: const TextStyle(
                                            color: Color(0xFF5B677A),
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _BadgePill(
                                        label: badgeStyle.label,
                                        background: badgeStyle.background,
                                        foreground: badgeStyle.foreground,
                                      ),
                                      if (expiryBadgeStyle != null)
                                        _BadgePill(
                                          label: expiryBadgeStyle.label,
                                          background: expiryBadgeStyle.background,
                                          foreground: expiryBadgeStyle.foreground,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 13,
                                    color: Color(0xFF7B879C),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _credentialDate(item),
                                    style: const TextStyle(
                                      color: Color(0xFF4C5A73),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _MetaLine(
                                label: 'Expiration',
                                value: expirationDate,
                              ),
                              const SizedBox(height: 4),
                              _MetaLine(
                                label: 'Last update',
                                value: lastUpdate,
                              ),
                              const SizedBox(height: 4),
                              _MetaLine(
                                label: 'HR Note',
                                value: hrNote,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _CardActionButton(
                                    onPressed: () => _viewFile(item),
                                    icon: Icons.visibility_outlined,
                                    label: 'View',
                                  ),
                                  const SizedBox(width: 8),
                                  _CardActionButton(
                                    onPressed: () =>
                                        _confirmDeleteCredential(item),
                                    icon: Icons.delete_outline,
                                    label: 'Delete',
                                    foreground: const Color(0xFFB3261E),
                                    borderColor: const Color(0xFFF1CBD1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatusBadgeStyle {
  const _StatusBadgeStyle({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}

class _CredentialTypeStyle {
  const _CredentialTypeStyle({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
}

class _ExpiryBadgeStyle {
  const _ExpiryBadgeStyle({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.foreground = const Color(0xFF334155),
    this.borderColor = const Color(0xFFDCE3EE),
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color foreground;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 32),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          side: BorderSide(color: borderColor),
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Color(0xFF6C788D),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
