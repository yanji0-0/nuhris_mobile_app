import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../navigation/app_nav.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

class CredentialUploadScreen extends StatefulWidget {
  const CredentialUploadScreen({
    super.key,
    required this.onNavigate,
    required this.onSubmitted,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final Future<void> Function() onSubmitted;

  @override
  State<CredentialUploadScreen> createState() => _CredentialUploadScreenState();
}

class _CredentialUploadScreenState extends State<CredentialUploadScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _expirationDate;
  String? _credentialType;
  String? _department;
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

  final List<String> _departmentOptions = const [
    'ASP',
    'SABM - School of Accountancy, Business and Management',
    'SACE - School of Architecture, Computing and Engineering',
    'SAHS - School of Allied Health and Sciences',
    'SHS - Senior High School',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to read selected file.')),
        );
        return;
      }

      final maxSizeBytes = 10 * 1024 * 1024;
      if (bytes.length > maxSizeBytes) {
        if (!mounted) {
          return;
        }
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
      if (!mounted) {
        return;
      }
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

            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B2F36),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profile Information',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),

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
                              child: Text(t, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _credentialType = v),
                    ),

                    const SizedBox(height: 10),
                    const _FieldLabel('Title'),
                    TextField(
                      controller: _titleController,
                      decoration: _inputDecoration().copyWith(
                        hintText: 'e.g., PRC License 2025',
                      ),
                    ),

                    const SizedBox(height: 10),
                    const _FieldLabel('Department'),
                    DropdownButtonFormField<String>(
                      initialValue: _department,
                      isExpanded: true,
                      hint: const Text('Select department'),
                      decoration: _inputDecoration(),
                      selectedItemBuilder: (context) => _departmentOptions
                          .map(
                            (d) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                d,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      items: _departmentOptions
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text(d, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _department = v),
                    ),

                    const SizedBox(height: 10),
                    const _FieldLabel('Expiration Date'),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(6),
                      child: InputDecorator(
                        decoration: _inputDecoration(),
                        child: Text(
                          _formatDate(_expirationDate),
                          style: TextStyle(
                            color: _expirationDate == null
                                ? Colors.black54
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    const _FieldLabel('Description'),
                    TextField(
                      controller: _descriptionController,
                      decoration: _inputDecoration().copyWith(
                        hintText: 'Additional Details....',
                      ),
                    ),

                    const SizedBox(height: 10),
                    const _FieldLabel('File Upload'),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isSubmitting ? null : _pickCredentialFile,
                        borderRadius: BorderRadius.circular(6),
                        child: Ink(
                          width: double.infinity,
                          height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFD6D6D6)),
                            color: const Color(0xFFF3F3F3),
                          ),
                          child: _selectedFile == null
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.upload_file_outlined, size: 18),
                                    SizedBox(height: 4),
                                    Text(
                                      'Click to upload (PDF, Image, DOC)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.mutedText,
                                      ),
                                    ),
                                  ],
                                )
                              : Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.insert_drive_file_outlined,
                                        size: 20,
                                        color: AppColors.primaryBlue,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedFile!.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _formatSize(
                                                _selectedFileBytes?.length ?? 0,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.mutedText,
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
                                                  _selectedFile = null;
                                                  _selectedFileBytes = null;
                                                });
                                              },
                                        icon: const Icon(Icons.close, size: 18),
                                        tooltip: 'Remove file',
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                if (_credentialType == null ||
                                    _titleController.text.trim().isEmpty) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Credential type and title are required.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (_selectedFile == null ||
                                    _selectedFileBytes == null) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please upload a file before submitting.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                setState(() => _isSubmitting = true);
                                try {
                                  final account = await ApiClient.instance
                                      .getAccount();
                                  final employee =
                                      (account['employee'] as Map?)
                                          ?.cast<String, dynamic>() ??
                                      {};
                                  final employeeId = employee['id'];
                                  final employeeAlternateId =
                                      employee['employee_id'];
                                  final credentialEmployeeId = employeeId;

                                  if (credentialEmployeeId == null) {
                                    throw Exception(
                                      'Employee profile not found for this account.',
                                    );
                                  }

                                  final uploadedFilePath = await ApiClient
                                      .instance
                                      .uploadEmployeeCredentialFile(
                                        employeeId: employeeId,
                                        employeeAlternateId:
                                            employeeAlternateId,
                                        fileBytes: _selectedFileBytes!,
                                        originalFileName: _selectedFile!.name,
                                      );

                                  await ApiClient.instance
                                      .createEmployeeCredential({
                                        'employee_id': credentialEmployeeId,
                                        'credential_type': _mapCredentialType(
                                          _credentialType!,
                                        ),
                                        'title': _titleController.text.trim(),
                                        'description': _descriptionController
                                            .text
                                            .trim(),
                                        'expires_at': _expirationDate
                                            ?.toIso8601String(),
                                        'status': 'pending',
                                        'department_id': null,
                                        'file_path': uploadedFilePath,
                                      });

                                  await widget.onSubmitted();
                                  if (!context.mounted) {
                                    return;
                                  }
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Credential submitted successfully.',
                                      ),
                                    ),
                                  );
                                  Navigator.pop(context);
                                } catch (error) {
                                  if (!context.mounted) {
                                    return;
                                  }
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Submit failed: $error'),
                                    ),
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() => _isSubmitting = false);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF014A8D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Submit Credential',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
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
      fillColor: const Color(0xFFF0F0F0),
      hintStyle: const TextStyle(color: Colors.black45),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.3),
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
