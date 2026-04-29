import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

class WFHMonitoringUploadScreen extends StatefulWidget {
  const WFHMonitoringUploadScreen({super.key});

  @override
  State<WFHMonitoringUploadScreen> createState() => _WFHMonitoringUploadScreenState();
}

class _WFHMonitoringUploadScreenState extends State<WFHMonitoringUploadScreen> {
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
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => _timeIn = picked);
  }

  Future<void> _pickTimeOut() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => _timeOut = picked);
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(withData: true);
    if (res == null) return;
    setState(() => _file = res.files.first);
  }

  String _formatDate(DateTime d) => '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
  String _formatTime(TimeOfDay t) => t.format(context);

  Future<void> _submit() async {
    if (_wfhDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a WFH date.')));
      return;
    }
    if (_file == null || _file!.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please choose a file to upload.')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final account = await ApiClient.instance.getAccount();
      final employee = (account['employee'] as Map?)?.cast<String, dynamic>() ?? {};
      final employeeId = employee['id'];

      if (employeeId == null) {
        throw Exception('Employee ID not found.');
      }

      final bytes = _file!.bytes as Uint8List;
      final originalName = _file!.name;

      final savedPath = await ApiClient.instance.uploadEmployeeCredentialFile(
        employeeId: employeeId,
        employeeAlternateId: employee['employee_id'],
        fileBytes: bytes,
        originalFileName: originalName,
      );

      // savedPath is a string like 'bucket/prefix/file'
      String filePathString = savedPath;

      try {
        await ApiClient.instance.submitWfhMonitoring(
          employeeId: employeeId,
          wfhDate: _wfhDate!.toIso8601String(),
          timeIn: _timeIn != null ? '${_timeIn!.hour.toString().padLeft(2,'0')}:${_timeIn!.minute.toString().padLeft(2,'0')}' : null,
          timeOut: _timeOut != null ? '${_timeOut!.hour.toString().padLeft(2,'0')}:${_timeOut!.minute.toString().padLeft(2,'0')}' : null,
          filePath: filePathString,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WFH monitoring uploaded.')));
        Navigator.pop(context);
        return;
      } catch (error) {
        // Insertion failed but file uploaded. Show message and return.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File uploaded but submission save failed: $error')));
        Navigator.pop(context);
        return;
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $error')));
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Upload WFH Sheet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('Any file type is accepted. HR will review the upload first, then approve or decline it.'),
                  const SizedBox(height: 16),

                  const Text('WFH Date', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        hintText: 'Select date',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      child: Text(_wfhDate != null ? _formatDate(_wfhDate!) : 'mm/dd/yyyy'),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Time In', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickTimeIn,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  hintText: '--:--',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                ),
                                child: Text(_timeIn != null ? _formatTime(_timeIn!) : '--:--'),
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
                            const Text('Time Out', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickTimeOut,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  hintText: '--:--',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                ),
                                child: Text(_timeOut != null ? _formatTime(_timeOut!) : '--:--'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Text('Monitoring Sheet', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),

                  // File picker container (full width, bordered)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE3E8F2)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed: _pickFile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.navy,
                            elevation: 0,
                            side: const BorderSide(color: Color(0xFFCCD6E6)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('Choose File', style: TextStyle(color: Color(0xFF2B2F36))),
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
                          'Select a date and file before submitting.',
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Submit Monitoring Sheet', style: TextStyle(fontWeight: FontWeight.w700)),
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
