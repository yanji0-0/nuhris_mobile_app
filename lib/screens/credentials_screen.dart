import 'package:flutter/material.dart';
import '../navigation/app_nav.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
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

  final tabs = const [
    'All',
    'Resume',
    'PRC License',
    'Seminars',
    'Degrees',
    'Ranking',
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
    if (selectedTab == 0) {
      return _credentials;
    }

    const tabToType = {
      1: 'resume',
      2: 'prc',
      3: 'seminars',
      4: 'degrees',
      5: 'ranking',
    };
    final expectedType = tabToType[selectedTab];
    if (expectedType == null) {
      return _credentials;
    }
    return _credentials.where((item) {
      final rawType = (item['credential_type'] ?? '').toString();
      return _normalizeCredentialType(rawType) == expectedType;
    }).toList();
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
    if (value.contains('ranking')) {
      return 'ranking';
    }
    return value;
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
        backgroundColor: const Color(0xFF0A1B66),
        foregroundColor: Colors.white,
        surfaceTintColor: const Color(0xFF0A1B66),
        elevation: 0,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('Credentials'),
        actions: [
          IconButton(
            onPressed: () => widget.onNavigate(AppNavItem.notifications),
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload and manage your credentials. HR will review and verify submissions.',
              style: TextStyle(color: AppColors.mutedText),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text(
                  'Upload New',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B2F36),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CredentialUploadScreen(
                        onNavigate: widget.onNavigate,
                        onSubmitted: _loadCredentials,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFB3B3B3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(tabs.length, (i) {
                    final selected = i == selectedTab;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => selectedTab = i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFE6E6E6)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            tabs[i],
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: selected ? Colors.black : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text('Failed to load credentials: $_error'))
                  : _filteredCredentials.isEmpty
                  ? Center(
                      child: Text(
                        'No credentials found. Upload\nyour first credential above',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.25),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredCredentials.length,
                      itemBuilder: (context, index) {
                        final item = _filteredCredentials[index];
                        final rawStatus = (item['status'] ?? 'pending')
                            .toString();
                        final badgeStyle = _statusBadgeStyle(rawStatus);
                        return Card(
                          child: ListTile(
                            title: Text(
                              (item['title'] ?? 'Credential').toString(),
                            ),
                            subtitle: Text(
                              (item['credential_type'] ?? '').toString(),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: badgeStyle.background,
                                borderRadius: BorderRadius.circular(999),
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
                          ),
                        );
                      },
                    ),
            ),
          ],
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
