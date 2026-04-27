import 'package:flutter/material.dart';

import '../navigation/app_nav.dart';
import '../services/api_client.dart';
import '../widgets/app_drawer.dart';
import 'credential_upload_screen.dart';

class CredentialsScreen extends StatefulWidget {
  const CredentialsScreen({
    super.key,
    required this.onNavigate,
    required this.onSignOut,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
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
      final data = await ApiClient.instance.getEmployeeCredentials();
      if (!mounted) {
        return;
      }
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE3E8F2)),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(tabs.length, (index) {
                            final selected = index == selectedTab;
                            return Padding(
                              padding: EdgeInsets.only(
                                right: index == tabs.length - 1 ? 0 : 8,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: () =>
                                    setState(() => selectedTab = index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFF0A2E86)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: Text(
                                    '${tabs[index]} (${_tabCountAt(index)})',
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFF58657A),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
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

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE6ECF6)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0B0B1E43),
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: typeStyle.background,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  typeStyle.icon,
                                  color: typeStyle.foreground,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF141B2E),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: badgeStyle.background,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            badgeStyle.label,
                                            style: TextStyle(
                                              color: badgeStyle.foreground,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _displayTypeLabel(rawType),
                                      style: const TextStyle(
                                        color: Color(0xFF2A324A),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_outlined,
                                          size: 14,
                                          color: Color(0xFF7B879C),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            _credentialDate(item),
                                            style: const TextStyle(
                                              color: Color(0xFF4C5A73),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          size: 18,
                                          color: Color(0xFF8A95A8),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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
