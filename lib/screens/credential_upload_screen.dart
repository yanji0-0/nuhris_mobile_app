import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CredentialUploadScreen extends StatefulWidget {
  const CredentialUploadScreen({super.key});

  @override
  State<CredentialUploadScreen> createState() => _CredentialUploadScreenState();
}

class _CredentialUploadScreenState extends State<CredentialUploadScreen> {
  final _titleController = TextEditingController();
  final _departmentController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _expirationDate;
  String? _credentialType;

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
    _departmentController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credentials'),
        actions: [
          IconButton(
            onPressed: () {},
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),

                    const _FieldLabel('Credential Type'),
                    DropdownButtonFormField<String>(
                      value: _credentialType,
                      hint: const Text('Select type'),
                      decoration: _inputDecoration(),
                      items: _types
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
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
                    TextField(
                      controller: _departmentController,
                      decoration: _inputDecoration().copyWith(
                        hintText: 'e.g., 1st Sem 2025-2026',
                      ),
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
                    Container(
                      width: double.infinity,
                      height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFD6D6D6)),
                        color: const Color(0xFFF3F3F3),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_file_outlined, size: 18),
                          SizedBox(height: 4),
                          Text(
                            'Click to upload (PDF, Image, DOC)',
                            style: TextStyle(fontSize: 12, color: AppColors.mutedText),
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF014A8D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        child: const Text(
                          'Submit Credential',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
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
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}