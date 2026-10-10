import 'package:flutter/material.dart';

import '../utils/app_log.dart';

/// Post-login gate showing the same Privacy Notice as the web portal
/// (`resources/views/privacy/notice.blade.php`). The employee must tick the
/// acknowledgment before Continue is enabled, or may log out instead.
///
/// [PrivacyNoticeScreen.readOnly] reopens the same notice from the app menu
/// at any time, without the acknowledgment controls.
class PrivacyNoticeScreen extends StatefulWidget {
  const PrivacyNoticeScreen({
    super.key,
    required this.version,
    required Future<void> Function() this.onContinue,
    required Future<void> Function() this.onLogout,
  });

  const PrivacyNoticeScreen.readOnly({super.key, required this.version})
      : onContinue = null,
        onLogout = null;

  final String version;

  /// Records the acknowledgment; throws if it could not be saved.
  final Future<void> Function()? onContinue;
  final Future<void> Function()? onLogout;

  bool get _readOnly => onContinue == null;

  @override
  State<PrivacyNoticeScreen> createState() => _PrivacyNoticeScreenState();
}

class _PrivacyNoticeScreenState extends State<PrivacyNoticeScreen> {
  static const _navy = Color(0xFF00386F);
  static const _headingColor = Color(0xFF1F2B5D);

  bool _acknowledged = false;
  bool _busy = false;

  Future<void> _continue() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onContinue!();
    } catch (error) {
      appLog('Privacy Notice acknowledgment failed', error.runtimeType);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to save your acknowledgment. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      await widget.onLogout!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECEEF1),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: _buildNotice(),
                  ),
                ),
              ),
            ),
            widget._readOnly ? _buildCloseFooter() : _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: _navy,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'NATIONAL UNIVERSITY',
                  style: TextStyle(
                    color: Color(0xFFBFDBFE),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x66BFDBFE)),
                ),
                child: Text(
                  'Version ${widget.version}',
                  style: const TextStyle(
                    color: Color(0xFFDBEAFE),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'National University HR Platform Privacy Notice',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget._readOnly
                ? 'Notice you acknowledged when signing in'
                : 'Please read and accept before continuing',
            style: TextStyle(color: Color(0xFFDBEAFE), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: FilledButton(
        onPressed: () => Navigator.of(context).maybePop(),
        style: FilledButton.styleFrom(
          backgroundColor: _navy,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'Close',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _busy
                ? null
                : () => setState(() => _acknowledged = !_acknowledged),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _acknowledged,
                  activeColor: _navy,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: _busy
                      ? null
                      : (value) =>
                          setState(() => _acknowledged = value ?? false),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'I have read and understand the National University HR '
                      'Platform Privacy Notice.',
                      style: TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _logout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Log out',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  // Disabled until the acknowledgment is ticked.
                  onPressed: _acknowledged && !_busy ? _continue : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _navy,
                    disabledBackgroundColor: _navy.withValues(alpha: 0.45),
                    disabledForegroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'You may log out without accepting this notice.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('1. Introduction', [
          _para(
            'The National University HR Platform processes personal '
            'information necessary to provide HR-related services and operate '
            'the platform. This includes employee administration, '
            'authentication, degree information, timekeeping, leave and '
            'schedule management, work-from-home monitoring, notifications, '
            'reporting, and system security.',
          ),
        ]),
        _section('2. Personal Data We Collect', [
          _sub(
            'Identity and employment information',
            'Employee ID, first name, last name, email address, department, '
                'position, employee type, faculty ranking, employment status, '
                'hire date, and official work schedule or time information.',
          ),
          _sub(
            'Account and authentication information',
            'Account name, email address, password hashes, role, '
                'email-verification status, password-reset information, '
                'session information, IP address, and user-agent information.',
          ),
          _sub(
            'Degree information',
            'Degree level, degree title, description, submitted document '
                'details, submission status, reviewer, review date, and review '
                'notes. Degree documents may contain additional information '
                'depending on what the employee submits.',
          ),
          _sub(
            'Attendance and DTR information',
            'Attendance dates, time-in, time-out, scheduled times, tardiness, '
                'undertime, overtime, schedule status, attendance status, and '
                'system-generated attendance notes or calculations.',
          ),
          _sub(
            'Leave information',
            'Leave type, leave dates, leave reason, days deducted, leave '
                'status, cutoff date, and remaining leave balances.',
          ),
          _sub(
            'Schedule information',
            'Submitted terms or academic years, working days, work '
                'indicators, scheduled times, submission status, review '
                'information, and review notes.',
          ),
          _sub(
            'WFH monitoring information',
            'WFH dates, time-in and time-out information, monitoring link, '
                'submission status, reviewer information, and review notes.',
          ),
          _sub(
            'Notifications, announcements, and system activity',
            'Announcements, notification recipients, read status, read '
                'timestamps, redirect links, account activity, audit actions, '
                'audit descriptions, timestamps, IP addresses, and selected '
                'audit metadata.',
          ),
        ]),
        _section('3. Why We Process Personal Data', [
          _bullets(const [
            'Employee administration and maintenance of HR records.',
            'Account authentication, password management, session '
                'management, and security.',
            'Degree submission and review.',
            'Attendance and DTR management, calculations, and reporting.',
            'Leave management, leave balances, eligibility rules, and '
                'attendance updates.',
            'Schedule submission, review, approval, and attendance '
                'evaluation.',
            'WFH monitoring, review, and attendance validation.',
            'Operational notifications and announcements.',
            'Reports, DTR exports, administrative oversight, auditing, and '
                'security monitoring.',
            'Automated processing of imported records and system-generated '
                'attendance calculations.',
          ]),
        ]),
        _section('4. Automated Processing and Document Extraction', [
          _rich([
            const TextSpan(text: 'Biometric DTR PDF files are processed using '),
            _bold('smalot/pdfparser'),
            const TextSpan(
              text:
                  '. The system extracts text and uses recognized employee, '
                  'date, and time values to create or update structured '
                  'attendance records.',
            ),
          ]),
          _rich([
            const TextSpan(text: 'Excel files are processed using '),
            _bold('PhpSpreadsheet'),
            const TextSpan(
              text:
                  '. The system extracts relevant date, time, employee, '
                  'leave, and status values from supported spreadsheets to '
                  'create or update structured attendance or leave records.',
            ),
          ]),
          _para(
            'The system can automatically calculate attendance-related '
            'information such as tardiness, undertime, overtime, schedule '
            'status, and attendance status. HR/Admin workflows remain '
            'involved in reviewing and approving relevant records.',
          ),
        ]),
        _section('5. Role-Based Access', [
          _labeled(
            'Employee:',
            'Primarily accesses their own profile and HR records. Employees '
                'can manage their own degree information, schedules, WFH '
                'submissions, account information, and notifications, and '
                'view their own HR-related information available through the '
                'employee module.',
          ),
          _labeled(
            'HR:',
            'Can access and manage employee HR records needed for HR '
                'operations, including employee records, degree information, '
                'DTRs, leave information, schedules, WFH submissions, '
                'announcements, and related review workflows according to the '
                'implemented permissions.',
          ),
          _labeled(
            'Admin:',
            'Has broader administrative access, including employee '
                'management, degree information and document deletion, DTR and '
                'WFH administration, schedule administration, role management, '
                'configuration, reports, and audit logs according to the '
                'implemented permissions.',
          ),
        ]),
        _section('6. Third-Party and External Services', [
          _labeledBullets(const [
            (
              'Supabase PostgreSQL:',
              'The configured application database stores HR platform '
                  'records.',
            ),
            (
              'Supabase Storage:',
              'Submitted degree documents are stored in the configured '
                  'storage bucket and are accessed through temporary signed '
                  'URLs.',
            ),
            (
              'Supabase Auth Admin API:',
              'User email, role-related metadata, and password '
                  'synchronization data may be sent for account provisioning, '
                  'password updates, or account deletion.',
            ),
            (
              'Gmail SMTP:',
              'The configured mail service is used for application email '
                  'workflows such as password resets and email verification.',
            ),
            (
              'Local processing libraries:',
              'smalot/pdfparser, PhpSpreadsheet, and DomPDF process imported '
                  'or generated documents within the application workflow.',
            ),
          ]),
          _para(
            'Hostinger is not identified in the code as receiving application '
            'data. It appears only in deployment-related comments.',
          ),
        ]),
        _section('7. Data Retention and Deletion', [
          _para(
            'The platform provides deletion or clearing functions for certain '
            'employee records, degree records and documents, attendance/DTR '
            'records, leave records, WFH records, schedule records, '
            'notifications, announcements, and other administrative records '
            'where applicable.',
          ),
          _para(
            'Specific retention periods are not currently defined in the '
            'application code. Personal data is retained only for as long as '
            'necessary for the applicable HR, operational, legal, or '
            'institutional requirements. Specific retention periods may be '
            'governed by applicable National University policies and '
            'records-management requirements. This statement does not '
            'establish or claim a specific National University retention '
            'period.',
          ),
        ]),
        _section('8. Security Measures', [
          _bullets(const [
            'Session-based authentication and role-based middleware.',
            'Password hashing, password-reset expiration, and login rate '
                'limiting.',
            'Session regeneration after login and session invalidation on '
                'logout.',
            'CSRF protection and input/file validation.',
            'Ownership checks for employee degree documents and WFH '
                'submission access.',
            'Temporary signed Supabase Storage URLs for file viewing.',
            'Database SSL requirement in the configured environment.',
            'Audit logging and filtering of passwords, tokens, keys, secrets, '
                'and uploaded file values from audit metadata.',
          ]),
          _para(
            'The application does not claim end-to-end encryption, '
            'multi-factor authentication, database-column encryption, '
            'complete production HTTPS enforcement, or database row-level '
            'security based on the current code.',
          ),
        ]),
        _section('9. Data Sources', [
          _para(
            'Personal data may come from employees, HR personnel, '
            'administrators, submitted degree documents, imported biometric '
            'DTR PDFs, imported leave Excel files, WFH submissions and '
            'monitoring links, schedule submissions, authentication and '
            'session activity, and system-generated calculations.',
          ),
        ]),
        _section('10. Data Subject Rights', [
          _para(
            'Subject to applicable law, including the Philippine Data Privacy '
            'Act of 2012 (Republic Act No. 10173), data subjects may have '
            'rights such as the right to be informed, right to access, right '
            'to correct, right to object, right to suspend or withdraw '
            'consent where applicable, right to erasure or blocking where '
            'applicable, right to data portability where applicable, and '
            'right to file a complaint.',
          ),
          _para(
            'The applicable rights and legal bases may depend on the specific '
            'processing activity. Processing in this HR platform is not '
            'represented as being based solely on consent.',
          ),
        ]),
        _section('11. Privacy Contact', [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Text(
              '[Official NU Data Privacy Office contact information to be '
              'provided by National University]',
              style: TextStyle(
                color: Color(0xFF78350F),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          _para(
            'No official DPO or privacy contact has been configured in this '
            'capstone implementation.',
          ),
        ], last: true),
      ],
    );
  }

  // ---------------------------------------------------------------- helpers

  static const _bodyStyle = TextStyle(
    color: Color(0xFF334155),
    fontSize: 14,
    height: 1.55,
  );

  Widget _section(String title, List<Widget> children, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _headingColor,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _para(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(text, style: _bodyStyle),
    );
  }

  TextSpan _bold(String text) {
    return TextSpan(
      text: text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
      ),
    );
  }

  Widget _rich(List<InlineSpan> spans) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text.rich(TextSpan(style: _bodyStyle, children: spans)),
    );
  }

  Widget _sub(String heading, String body) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          Text(body, style: _bodyStyle),
        ],
      ),
    );
  }

  Widget _labeled(String label, String body) {
    return _rich([_bold(label), TextSpan(text: ' $body')]);
  }

  Widget _bulletRow(Widget child) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, right: 8),
            child: Text('•', style: _bodyStyle),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _bullets(List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        children: [
          for (final item in items) _bulletRow(Text(item, style: _bodyStyle)),
        ],
      ),
    );
  }

  Widget _labeledBullets(List<(String, String)> items) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        children: [
          for (final (label, body) in items)
            _bulletRow(
              Text.rich(
                TextSpan(
                  style: _bodyStyle,
                  children: [_bold(label), TextSpan(text: ' $body')],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
