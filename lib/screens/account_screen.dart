import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/app_nav.dart';
import '../providers/account_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/nuhris_app_bar.dart';
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
  final List<_EmployeeTypeOption> employeeTypes = const [
    _EmployeeTypeOption(value: 'Faculty', label: 'Faculty'),
    _EmployeeTypeOption(value: 'Security', label: 'Security'),
    _EmployeeTypeOption(value: 'ASP', label: 'Admin Support Personel'),
  ];

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

    return Scaffold(
      drawer: AppDrawer(
        selected: AppNavItem.account,
        onSelect: (item) {
          Navigator.pop(context);
          widget.onNavigate(item);
        },
      ),
      appBar: NuhrisAppBar(
        title: 'Account',
        currentItem: AppNavItem.account,
        onNavigate: widget.onNavigate,
        onSignOut: widget.onSignOut,
      ),
      body: accountAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load account: $error'),
          ),
        ),
        data: (payload) {
          final user =
              (payload['user'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
          final employee =
              (payload['employee'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
          final department =
              (employee['department'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};

          final firstName = (employee['first_name'] ?? '').toString().trim();
          final lastName = (employee['last_name'] ?? '').toString().trim();
          final fullName = [firstName, lastName]
              .where((part) => part.isNotEmpty)
              .join(' ')
              .trim();
          final displayName = fullName.isNotEmpty
              ? fullName
              : (user['name'] ?? 'Employee').toString();
          final displayEmail =
              (employee['email'] ?? user['email'] ?? '').toString();
          final employeeType =
              _displayEmployeeType(_normalizeEmployeeType(employee['employment_type']));

          return ListView(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 18),
            children: [
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
                              backgroundColor: const Color(0xFFE8F0FA),
                              child: Text(
                                employeeInitialsFromAccount(payload),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF102A72),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayEmail.isEmpty ? 'No email on record' : displayEmail,
                            style: const TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
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
                            _ReadOnlyDetailField(label: 'NAME', value: displayName),
                            const SizedBox(height: 18),
                            _ReadOnlyDetailField(label: 'EMAIL', value: displayEmail),
                            const SizedBox(height: 18),
                            _ReadOnlyDetailField(
                              label: 'DEPARTMENT',
                              value: (department['name'] ?? '').toString(),
                            ),
                            const SizedBox(height: 18),
                            _ReadOnlyDetailField(
                              label: 'POSITION',
                              value: (employee['position'] ?? '').toString(),
                            ),
                            const SizedBox(height: 18),
                            _ReadOnlyDetailField(
                              label: 'EMPLOYEE TYPE',
                              value: employeeType,
                            ),
                            const SizedBox(height: 18),
                            _ReadOnlyDetailField(
                              label: 'EMPLOYEE ID',
                              value: (employee['employee_id'] ?? '').toString(),
                            ),
                            const SizedBox(height: 18),
                            _ReadOnlyDetailField(
                              label: 'DATE HIRED',
                              value: _formatDate(
                                (employee['hire_date'] ?? '').toString(),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _ReadOnlyDetailField(
                              label: 'PHONE',
                              value: (employee['phone'] ?? '').toString(),
                            ),
                            const SizedBox(height: 18),
                            _ReadOnlyDetailField(
                              label: 'ADDRESS',
                              value: (employee['address'] ?? '').toString(),
                            ),
                          ],
                        ),
                      ),
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

  String _formatDate(String value) {
    if (value.length < 10) {
      return value;
    }
    final date = value.substring(0, 10).split('-');
    if (date.length != 3) {
      return value;
    }
    return '${date[1]}/${date[2]}/${date[0]}';
  }

  String _displayEmployeeType(String? employeeType) {
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
