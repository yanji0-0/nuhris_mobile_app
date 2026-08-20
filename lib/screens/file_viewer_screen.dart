import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

class FileViewerScreen extends StatefulWidget {
  const FileViewerScreen({super.key, required this.url, this.title});

  final String url;
  final String? title;

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  bool _loading = true;
  bool _loadFailed = false;
  String _errorMessage = '';
  Uint8List? _bytes;
  String? _contentType;
  PdfControllerPinch? _pdfController;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  String _extensionFromUrl(String url) {
    final path = (Uri.tryParse(url)?.path ?? url).toLowerCase();
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    return path.substring(dot + 1);
  }

  bool _isPdf(String contentType, String ext) {
    final ct = contentType.toLowerCase();
    return ct.contains('application/pdf') || ext == 'pdf';
  }

  bool _isImage(String contentType, String ext) {
    final ct = contentType.toLowerCase();
    if (ct.startsWith('image/')) return true;
    return ext == 'png' ||
        ext == 'jpg' ||
        ext == 'jpeg' ||
        ext == 'gif' ||
        ext == 'webp';
  }

  Future<void> _loadFile() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
      _errorMessage = '';
    });

    try {
      final response = await http
          .get(Uri.parse(widget.url))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'HTTP ${response.statusCode} while downloading file.',
        );
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        throw Exception('Downloaded file was empty.');
      }

      final contentType = response.headers['content-type'] ?? '';
      final ext = _extensionFromUrl(widget.url);

      PdfControllerPinch? pdfController;
      if (_isPdf(contentType, ext)) {
        pdfController = PdfControllerPinch(
          document: PdfDocument.openData(bytes),
        );
      } else if (!_isImage(contentType, ext)) {
        throw Exception(
          'Unsupported file type'
          '${contentType.isNotEmpty ? ' ($contentType)' : ''}.',
        );
      }

      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _contentType = contentType;
        _pdfController = pdfController;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? 'File Viewer';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading file...'),
          ],
        ),
      );
    }

    if (_loadFailed) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Unable to load file',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadFile,
              child: const Text('Retry'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    final bytes = _bytes;
    if (bytes == null) {
      return const Center(child: Text('No file data.'));
    }

    final ext = _extensionFromUrl(widget.url);
    final contentType = _contentType ?? '';

    if (_isPdf(contentType, ext) && _pdfController != null) {
      return PdfViewPinch(controller: _pdfController!);
    }

    if (_isImage(contentType, ext)) {
      return InteractiveViewer(
        child: Center(
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                Center(child: Text('Unable to display image:\n$error')),
          ),
        ),
      );
    }

    return const Center(child: Text('Unsupported file type.'));
  }
}
