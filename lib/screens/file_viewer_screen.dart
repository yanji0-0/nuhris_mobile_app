import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class FileViewerScreen extends StatefulWidget {
  const FileViewerScreen({super.key, required this.url, this.title});

  final String url;
  final String? title;

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _loadFailed = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (err) {
          if (mounted) {
            setState(() {
              _loading = false;
              _loadFailed = true;
              _errorMessage = err.description;
            });
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
    
    // Timeout: if still loading after 10 seconds, show error
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _loading) {
        setState(() {
          _loading = false;
          _loadFailed = true;
          _errorMessage = 'URL load timeout. The file URL may be invalid or unreachable.';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? 'File Viewer';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading file...'),
                ],
              ),
            ),
          if (_loadFailed)
            Center(
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
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
