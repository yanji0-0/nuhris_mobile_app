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

  /// Logs technical details for developers only; the signed URL's token
  /// (query string) is stripped so it never reaches logs or the UI.
  void _logError(String stage, Object error) {
    final safeUrl = widget.url.split('?').first;
    final details = error.toString().replaceAll(widget.url, safeUrl);
    debugPrint('FileViewer $stage failed for $safeUrl: $details');
  }

  Future<void> _loadFile() async {
    _pdfController?.dispose();
    setState(() {
      _pdfController = null;
      _loading = true;
      _loadFailed = false;
    });

    try {
      final response = await http
          .get(Uri.parse(widget.url))
          .timeout(const Duration(seconds: 30));

      final head = response.bodyBytes.take(5).toList();
      debugPrint(
        'FileViewer download: ${widget.url.split('?').first} '
        'status=${response.statusCode} '
        'content-type=${response.headers['content-type']} '
        'bytes=${response.bodyBytes.length} '
        'starts-with-%PDF=${String.fromCharCodes(head) == '%PDF-'}',
      );

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
      _logError('download', error);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Unable to load this file',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to load this PDF. Please try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
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
      ),
    );
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
      return _buildError();
    }

    final bytes = _bytes;
    if (bytes == null) {
      return const Center(child: Text('No file data.'));
    }

    final ext = _extensionFromUrl(widget.url);
    final contentType = _contentType ?? '';

    if (_isPdf(contentType, ext) && _pdfController != null) {
      // pdfx reports renderer failures (e.g. PDF.js missing on web) as a
      // generic "Unknown error"; show the friendly message instead.
      return PdfViewPinch(
        controller: _pdfController!,
        builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          errorBuilder: (context, error) {
            _logError('render', error);
            return _buildError();
          },
        ),
      );
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
