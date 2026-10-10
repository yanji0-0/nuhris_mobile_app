import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../navigation/app_nav.dart';
import '../providers/account_provider.dart';
import '../providers/api_client_provider.dart';
import '../services/api_client.dart' show ApiException, userMessageFor;
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/nuhris_app_bar.dart';
import '../widgets/nuhris_website_card.dart';
import 'file_viewer_screen.dart';
import '../utils/employee_initials.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({
    super.key,
    required this.onNavigate,
    required this.onSignOut,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  String? employeeType;
  String _displayName = 'Employee';
  String _displayEmail = '';
  bool _isLoading = true;
  String? _profilePhotoUrl;

  final _employeeIdCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _dateHiredCtrl = TextEditingController();
  ProviderSubscription<AsyncValue<Map<String, dynamic>>>? _accountSubscription;
  ProviderSubscription<AsyncValue<String?>>? _profilePhotoSubscription;

  final List<_EmployeeTypeOption> employeeTypes = const [
    _EmployeeTypeOption(value: 'Faculty', label: 'Faculty'),
    _EmployeeTypeOption(value: 'Security', label: 'Security'),
    _EmployeeTypeOption(value: 'ASP', label: 'Admin Support Personel'),
  ];

  @override
  void initState() {
    super.initState();
    // Listen to account and profile photo providers and populate fields when data arrives.
    _accountSubscription = ref.listenManual<AsyncValue<Map<String, dynamic>>>(
      accountProvider,
      (prev, next) {
        // Background refreshes keep the current data instead of flipping the
        // page back to its loading state.
        next.when(
          skipLoadingOnReload: true,
          skipError: true,
          data: (payload) {
            final user =
                (payload['user'] as Map?)?.cast<String, dynamic>() ?? {};
            final employee =
                (payload['employee'] as Map?)?.cast<String, dynamic>() ?? {};
            final department =
                (employee['department'] as Map?)?.cast<String, dynamic>() ?? {};

            final firstName = (employee['first_name'] ?? '').toString().trim();
            final lastName = (employee['last_name'] ?? '').toString().trim();
            final empCombined = (lastName.isNotEmpty && firstName.isNotEmpty)
                ? '$lastName, $firstName'
                : ((employee['name'] ?? '').toString().trim());

            _displayName = empCombined.isNotEmpty
                ? empCombined
                : (user['name'] ?? 'Employee').toString();
            _displayEmail = (user['email'] ?? '').toString();

            _employeeIdCtrl.text = (employee['employee_id'] ?? '').toString();
            _departmentCtrl.text = (department['name'] ?? '').toString();
            _positionCtrl.text = (employee['position'] ?? '').toString();
            _dateHiredCtrl.text = _formatDate(
              (employee['hire_date'] ?? '').toString(),
            );
            employeeType = _normalizeEmployeeType(employee['employment_type']);

            if (mounted) setState(() => _isLoading = false);
          },
          loading: () {
            if (mounted) setState(() => _isLoading = true);
          },
          error: (_, _) {
            if (mounted) setState(() => _isLoading = false);
          },
        );
      },
      fireImmediately: true,
    );

    _profilePhotoSubscription = ref.listenManual<AsyncValue<String?>>(
      profilePhotoProvider,
      (prev, next) {
        next.when(
          data: (url) {
            if (url != null && url.trim().isNotEmpty) {
              if (mounted) setState(() => _profilePhotoUrl = url);
            }
          },
          loading: () {},
          error: (_, _) {},
        );
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _accountSubscription?.close();
    _profilePhotoSubscription?.close();
    _employeeIdCtrl.dispose();
    _departmentCtrl.dispose();
    _positionCtrl.dispose();
    _dateHiredCtrl.dispose();
    super.dispose();
  }

  // ignore: unused_element
  Future<void> _pickDateHired() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 60),
      lastDate: DateTime(now.year + 2),
    );

    if (picked == null) return;

    _dateHiredCtrl.text =
        '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
  }

  String? _normalizeEmployeeType(dynamic value) {
    final normalizedValue = value?.toString().trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }

    for (final option in employeeTypes) {
      if (normalizedValue == option.value ||
          normalizedValue.toLowerCase() == option.label.toLowerCase()) {
        return option.value;
      }
    }

    if (normalizedValue.toLowerCase() == 'admin support personel' ||
        normalizedValue.toLowerCase() == 'admin support personnel') {
      return 'ASP';
    }

    return null;
  }



  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(accountProvider);
    final initials = accountAsync.maybeWhen(
      skipLoadingOnReload: true,
      skipError: true,
      data: employeeInitialsFromAccount,
      orElse: () => 'E',
    );
    final ImageProvider<Object>? avatarImage =
        _profilePhotoUrl != null && _profilePhotoUrl!.trim().isNotEmpty
        ? NetworkImage(_profilePhotoUrl!.trim())
        : null;

    return Scaffold(
      drawer: AppDrawer(
        selected: AppNavItem.account,
        onSelect: (item) {
          Navigator.pop(context);
          widget.onNavigate(item);
        },
      ),
      appBar: NuhrisAppBar(
        title: 'Profile',
        currentItem: AppNavItem.account,
        onNavigate: widget.onNavigate,
        onSignOut: widget.onSignOut,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 18),
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Container(
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 31,
                          backgroundColor: const Color(0xFFE9EEF3),
                          backgroundImage: avatarImage,
                          child: avatarImage == null
                              ? Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Color(0xFF7B8794),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 28,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _displayEmail,
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile Information',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FBFF),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE1E8F4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'READ ONLY DETAILS',
                          style: TextStyle(
                            color: Color(0xFF657A99),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _ReadOnlyDetailField(
                          label: 'DEPARTMENT',
                          value: _departmentCtrl.text,
                        ),
                        const SizedBox(height: 18),
                        _ReadOnlyDetailField(
                          label: 'POSITION',
                          value: _positionCtrl.text,
                        ),
                        const SizedBox(height: 18),
                        _ReadOnlyDetailField(
                          label: 'EMPLOYEE TYPE',
                          value: _displayEmployeeType(),
                        ),
                        const SizedBox(height: 18),
                        _ReadOnlyDetailField(
                          label: 'EMPLOYEE ID',
                          value: _employeeIdCtrl.text,
                        ),
                        const SizedBox(height: 18),
                        _ReadOnlyDetailField(
                          label: 'DATE HIRED',
                          value: _dateHiredCtrl.text,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const _AcademicDegreesCard(),
          const SizedBox(height: 10),
          const NuhrisWebsiteCard(),
        ],
      ),
    );
  }

  /// Web profile format: `format('M d, Y')`, e.g. "Jul 07, 2023".
  String _formatDate(String value) {
    if (value.length < 10) {
      return value;
    }
    // Parse only the YYYY-MM-DD part so timezones can't shift the day.
    final date = DateTime.tryParse(value.substring(0, 10));
    if (date == null) {
      return value;
    }
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String _displayEmployeeType() {
    final value = employeeType;
    if (value == null || value.isEmpty) {
      return '';
    }

    for (final option in employeeTypes) {
      if (option.value == value) {
        return option.label;
      }
    }

    return value;
  }
}

class _EmployeeTypeOption {
  const _EmployeeTypeOption({required this.value, required this.label});

  final String value;
  final String label;
}

/// View-only list of the employee's academic degree submissions, laid out like
/// the web profile. Uploading/deleting stays on the NUHRIS Web Employee Portal.
class _AcademicDegreesCard extends ConsumerWidget {
  const _AcademicDegreesCard();

  // Same levels and labels as the web profile.
  static const _levels = <(String, String)>[
    ('undergraduate', 'Undergraduate Degree'),
    ('masters', "Master's Degree"),
    ('doctoral', 'Doctoral Degree'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final degreesAsync = ref.watch(employeeDegreesProvider);

    // Keep the current degrees visible during background refreshes so the
    // card does not collapse to a spinner (which shifted the scroll).
    final Widget body = degreesAsync.when(
      skipLoadingOnReload: true,
      skipError: true,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            userMessageFor(error),
            style: const TextStyle(color: AppColors.red, fontSize: 13),
          ),
          TextButton(
            onPressed: () => ref.invalidate(employeeDegreesProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (degrees) => Column(
        children: [
          for (final (level, label) in _levels) ...[
            _DegreeTile(
              label: label,
              // Web: `$degrees->firstWhere('degree_level', $level)`.
              degree: degrees
                  .where((d) => d['degree_level']?.toString() == level)
                  .firstOrNull,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Academic Degrees',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            body,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF1D4ED8),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'To submit or update your Undergraduate, Master\'s, or '
                      'Doctoral Degree documents, please use the NUHRIS Web '
                      'Employee Portal.',
                      style: TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DegreeTile extends ConsumerStatefulWidget {
  const _DegreeTile({required this.label, required this.degree});

  final String label;
  final Map<String, dynamic>? degree;

  @override
  ConsumerState<_DegreeTile> createState() => _DegreeTileState();
}

class _DegreeTileState extends ConsumerState<_DegreeTile> {
  bool _opening = false;

  /// View-only: signs the stored object key in the private "credentials"
  /// bucket (same path as WFH Monitoring) and opens the in-app PDF viewer.
  Future<void> _openPdf(String filePath) async {
    if (_opening) return;
    setState(() => _opening = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final url = await ref
          .read(apiClientProvider)
          .getCredentialFileUrl(filePath);
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        throw ApiException('The file for this degree could not be found.');
      }
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => FileViewerScreen(url: url, title: widget.label),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Unable to open this PDF right now. Please try again.',
          ),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _openPdf(filePath),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.degree;
    final label = widget.label;
    final status = (data?['status'] ?? '').toString().trim();
    final filePath = (data?['file_path'] ?? '').toString().trim();
    final fileName = (data?['original_filename'] ?? '').toString().trim();
    final notes = (data?['review_notes'] ?? '').toString().trim();
    final submittedAt = DateTime.tryParse(
      (data?['created_at'] ?? '').toString(),
    );

    // Web badge: green for verified, amber for any other status.
    final (String badgeText, Color badgeBg, Color badgeFg) = data == null
        ? ('Not Submitted', const Color(0xFFF1F5F9), const Color(0xFF475569))
        : status == 'verified'
        ? ('Verified', const Color(0xFFD1FAE5), const Color(0xFF047857))
        : (
            status.isEmpty
                ? 'Pending'
                : '${status[0].toUpperCase()}${status.substring(1)}',
            const Color(0xFFFEF3C7),
            const Color(0xFFB45309),
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E8F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeFg,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (data != null) ...[
            if (fileName.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 18,
                    color: Color(0xFF657A99),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (submittedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Submitted ${DateFormat('MMM dd, yyyy').format(submittedAt)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedText,
                ),
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'HR note: $notes',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
            ],
            if (filePath.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _opening ? null : () => _openPdf(filePath),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1D4ED8),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF93C5FD)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 34),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: _opening
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('View PDF'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ReadOnlyDetailField extends StatelessWidget {
  const _ReadOnlyDetailField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF657A99),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value.isEmpty ? '-' : value,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}
