import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/app_nav.dart';
import '../providers/api_client_provider.dart';
import '../theme/app_theme.dart';

class CredentialUploadScreen extends ConsumerStatefulWidget {
  const CredentialUploadScreen({
    super.key,
    required this.onNavigate,
    required this.onSubmitted,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final Future<void> Function() onSubmitted;

  @override
  ConsumerState<CredentialUploadScreen> createState() =>
      _CredentialUploadScreenState();
}

class _CredentialUploadScreenState
    extends ConsumerState<CredentialUploadScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _expirationDate;
  String? _credentialType;
  PlatformFile? _selectedFile;
  Uint8List? _selectedFileBytes;
  bool _isSubmitting = false;

  final List<String> _types = const [
    'Resume',
    'PRC License',
    'Seminar / Training',
    'Academic Degree',
    'Ranking File',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _requiresExpirationDate => _credentialType == 'PRC License';

  bool get _requiresTitle =>
      _credentialType == 'Seminar / Training' ||
      _credentialType == 'Academic Degree';

  void _onCredentialTypeChanged(String? value) {
    setState(() {
      _credentialType = value;
      if (!_requiresExpirationDate) {
        _expirationDate = null;
      }
      if (!_requiresTitle) {
        _titleController.clear();
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 20),
    );

    if (picked != null) {
      setState(() => _expirationDate = picked);
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'mm/dd/yyyy';
    return '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _pickCredentialFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      Uint8List? bytes = file.bytes;

      if (bytes == null && file.path != null && !kIsWeb) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to read selected file.')),
        );
        return;
      }

      const maxSizeBytes = 10 * 1024 * 1024;
      if (bytes.length > maxSizeBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File is too large. Max size is 10MB.')),
        );
        return;
      }

      setState(() {
        _selectedFile = file;
        _selectedFileBytes = bytes;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('File picker failed: $error')));
    }
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  String _resolveTitleForSubmit() {
    if (_requiresTitle) {
      return _titleController.text.trim();
    }

    switch (_credentialType) {
      case 'PRC License':
        return 'PRC License';
      case 'Ranking File':
        return 'Ranking File';
      case 'Resume':
      default:
        return 'Resume';
    }
  }

  Future<void> _submitCredential() async {
    final messenger = ScaffoldMessenger.of(context);

    if (_credentialType == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please select a credential type.')),
      );
      return;
    }

    if (_requiresTitle && _titleController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Title is required for this credential type.'),
        ),
      );
      return;
    }

    if (_requiresExpirationDate && _expirationDate == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please select an expiration date for PRC License.'),
        ),
      );
      return;
    }

    if (_selectedFile == null || _selectedFileBytes == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please upload a file before submitting.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(apiClientProvider);
      final account = await api.getAccount();
      final employee =
          (account['employee'] as Map?)?.cast<String, dynamic>() ?? {};
      final employeeId = employee['id'];
      final employeeAlternateId = employee['employee_id'];
      final credentialEmployeeId = employeeId;

      if (credentialEmployeeId == null) {
        throw Exception('Employee profile not found for this account.');
      }

      final uploadedFilePath = await api.uploadEmployeeCredentialFile(
        employeeId: employeeId,
        employeeAlternateId: employeeAlternateId,
        fileBytes: _selectedFileBytes!,
        originalFileName: _selectedFile!.name,
      );

      await api.createEmployeeCredential({
        'employee_id': credentialEmployeeId,
        'credential_type': _mapCredentialType(_credentialType!),
        'title': _resolveTitleForSubmit(),
        'description': _descriptionController.text.trim(),
        'expires_at': _requiresExpirationDate
            ? _expirationDate?.toIso8601String()
            : null,
        'status': 'pending',
        'department_id': null,
        'file_path': uploadedFilePath,
      });

      await widget.onSubmitted();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Credential submitted successfully.')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Submit failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload and manage your credentials. HR will review and verify submissions.',
              style: TextStyle(color: AppColors.mutedText, fontSize: 14),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 48,
                width: 112,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B2F36),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFB8C4D6), width: 0.8),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 1100;
                    final isMedium = constraints.maxWidth >= 760;
                    final fieldWidth = isWide
                        ? (constraints.maxWidth - 40) / 3
                        : isMedium
                        ? (constraints.maxWidth - 20) / 2
                        : constraints.maxWidth;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Credential Information',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 20,
                          runSpacing: 14,
                          children: [
                            SizedBox(
                              width: fieldWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _FieldLabel('Credential Type'),
                                  DropdownButtonFormField<String>(
                                    initialValue: _credentialType,
                                    isExpanded: true,
                                    hint: const Text('Select type'),
                                    decoration: _inputDecoration(),
                                    selectedItemBuilder: (context) => _types
                                        .map(
                                          (t) => Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              t,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    items: _types
                                        .map(
                                          (t) => DropdownMenuItem(
                                            value: t,
                                            child: Text(
                                              t,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: _onCredentialTypeChanged,
                                  ),
                                  if (_credentialType == 'Resume') ...[
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Resume must be re-uploaded one year from the upload date.',
                                      style: TextStyle(
                                        color: Color(0xFF0B4FD5),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                  if (_credentialType == 'PRC License') ...[
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Expiration date is required for PRC License.',
                                      style: TextStyle(
                                        color: AppColors.mutedText,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (_requiresExpirationDate)
                              SizedBox(
                                width: fieldWidth,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _FieldLabel('Expiration Date'),
                                    InkWell(
                                      onTap: _pickDate,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InputDecorator(
                                        decoration: _inputDecoration(),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _formatDate(_expirationDate),
                                                style: TextStyle(
                                                  color: _expirationDate == null
                                                      ? Colors.black54
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.calendar_today_outlined,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_requiresTitle)
                              SizedBox(
                                width: fieldWidth,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _FieldLabel('Title'),
                                    TextField(
                                      controller: _titleController,
                                      decoration: _inputDecoration().copyWith(
                                        hintText: 'Enter credential title',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            SizedBox(
                              width: fieldWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _FieldLabel('Notes / Details'),
                                  TextField(
                                    controller: _descriptionController,
                                    decoration: _inputDecoration().copyWith(
                                      hintText:
                                          'Optional notes or additional details',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _FieldLabel('File Upload'),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _isSubmitting
                                          ? null
                                          : _pickCredentialFile,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Ink(
                                        width: double.infinity,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFD3DDEA),
                                          ),
                                          color: const Color(0xFFF8FAFD),
                                        ),
                                        child: _selectedFile == null
                                            ? const Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.cloud_upload_outlined,
                                                    size: 30,
                                                    color: Color(0xFF8A9BB5),
                                                  ),
                                                  SizedBox(height: 10),
                                                  Text(
                                                    'Click to upload (PDF, Image, DOC · max 10 MB)',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Color(0xFF8293AD),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .insert_drive_file_outlined,
                                                      size: 24,
                                                      color:
                                                          AppColors.primaryBlue,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            _selectedFile!.name,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 13,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Text(
                                                            _formatSize(
                                                              _selectedFileBytes
                                                                      ?.length ??
                                                                  0,
                                                            ),
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              color: AppColors
                                                                  .mutedText,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    IconButton(
                                                      onPressed: _isSubmitting
                                                          ? null
                                                          : () {
                                                              setState(() {
                                                                _selectedFile =
                                                                    null;
                                                                _selectedFileBytes =
                                                                    null;
                                                              });
                                                            },
                                                      icon: const Icon(
                                                        Icons.close,
                                                        size: 18,
                                                      ),
                                                      tooltip: 'Remove file',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            height: 54,
                            width: 220,
                            child: ElevatedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : _submitCredential,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF014A8D),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Submit Credential',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _mapCredentialType(String type) {
    switch (type) {
      case 'Resume':
        return 'resume';
      case 'PRC License':
        return 'prc';
      case 'Seminar / Training':
        return 'seminars';
      case 'Academic Degree':
        return 'degrees';
      case 'Ranking File':
        return 'ranking';
      default:
        return 'resume';
    }
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      filled: true,
      fillColor: const Color(0xFFF8FAFD),
      hintStyle: const TextStyle(color: Colors.black45),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFB7C5D9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.6),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
