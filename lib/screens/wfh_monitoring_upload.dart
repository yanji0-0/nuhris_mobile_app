import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_refresh_provider.dart';
import '../providers/api_client_provider.dart';
import '../services/api_client.dart' show userMessageFor;
import '../theme/app_theme.dart';
import '../utils/upload_validation.dart';
import '../widgets/confirm_identity_dialog.dart';

class WFHMonitoringUploadScreen extends ConsumerStatefulWidget {
  const WFHMonitoringUploadScreen({super.key});

  @override
  ConsumerState<WFHMonitoringUploadScreen> createState() =>
      _WFHMonitoringUploadScreenState();
}

class _WFHMonitoringUploadScreenState
    extends ConsumerState<WFHMonitoringUploadScreen> {
  DateTime? _wfhDate;
  TimeOfDay? _timeIn;
  TimeOfDay? _timeOut;
  PlatformFile? _file;
  bool _isSubmitting = false;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _wfhDate = picked);
  }

  Future<void> _pickTimeIn() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _timeIn = picked);
  }

  Future<void> _pickTimeOut() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _timeOut = picked);
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedUploadExtensions,
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final file = res.files.first;
    // Validate immediately (size, extension and file signature) so the
    // employee gets feedback before anything is uploaded.
    final bytes = file.bytes;
    try {
      if (bytes == null) {
        throw const UploadValidationException('Unable to read this file.');
      }
      validateUpload(originalName: file.name, bytes: bytes);
    } on UploadValidationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    setState(() => _file = file);
  }

  String _formatDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
  String _formatTime(TimeOfDay t) => t.format(context);
  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_wfhDate == null) {
      _showMessage('Please select a WFH date.');
      return;
    }
    if (_timeIn == null || _timeOut == null) {
      _showMessage('Please enter the time in and time out.');
      return;
    }
    final timeIn = _hhmm(_timeIn!);
    final timeOut = _hhmm(_timeOut!);
    if (timeOut.compareTo(timeIn) <= 0) {
      _showMessage('The time out must be later than the time in.');
      return;
    }
    final bytes = _file?.bytes;
    if (_file == null || bytes == null) {
      _showMessage('Please choose a file to upload.');
      return;
    }

    // Submitting a record to HR is a sensitive operation: confirm identity.
    final confirmed = await confirmIdentity(
      context,
      ref,
      action: 'submit this WFH monitoring sheet',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(apiClientProvider);
      final validated = validateUpload(originalName: _file!.name, bytes: bytes);

      final savedPath = await api.uploadEmployeeCredentialFile(
        fileBytes: bytes,
        originalFileName: _file!.name,
      );

      await api.submitWfhMonitoring(
        wfhDate: _wfhDate!,
        timeIn: timeIn,
        timeOut: timeOut,
        filePath: savedPath,
        originalFilename: validated.displayFileName,
      );

      ref.read(appRefreshProvider.notifier).trigger();
      if (!mounted) return;
      _showMessage('WFH monitoring uploaded.');
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      _showMessage(userMessageFor(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload WFH Sheet'),
        backgroundColor: const Color(0xFF0A1B66),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload WFH Sheet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'PDF, JPG or PNG, up to 10 MB. HR will review the upload first, then approve or decline it.',
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'WFH Date',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        hintText: 'Select date',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      child: Text(
                        _wfhDate != null
                            ? _formatDate(_wfhDate!)
                            : 'mm/dd/yyyy',
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Time In',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickTimeIn,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  hintText: '--:--',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                                child: Text(
                                  _timeIn != null
                                      ? _formatTime(_timeIn!)
                                      : '--:--',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Time Out',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickTimeOut,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  hintText: '--:--',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                                child: Text(
                                  _timeOut != null
                                      ? _formatTime(_timeOut!)
                                      : '--:--',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'Monitoring Sheet',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),

                  // File picker container (full width, bordered)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE3E8F2)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed: _pickFile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.navy,
                            elevation: 0,
                            side: const BorderSide(color: Color(0xFFCCD6E6)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text(
                            'Choose File',
                            style: TextStyle(color: Color(0xFF2B2F36)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _file?.name ?? 'No file chosen',
                            style: const TextStyle(color: Color(0xFF374151)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Select a date, times and file before submitting.',
                          style: TextStyle(color: AppColors.mutedText),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                  'Submit Monitoring Sheet',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ],
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
