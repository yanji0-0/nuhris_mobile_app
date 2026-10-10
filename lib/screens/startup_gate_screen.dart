import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../utils/app_log.dart';

/// Full-screen notice shown before sign-in when a startup check fails:
/// blocked device/app integrity, a required update, or a warning the
/// employee must acknowledge.
class StartupGateScreen extends StatelessWidget {
  const StartupGateScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.messages,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final List<String> messages;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Opens an HTTPS update page in the browser / store.
  static Future<void> openUpdateUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      appLog('Update page failed to open', error.runtimeType);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: AppColors.navy),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 12),
                for (final message in messages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 16),
                  FilledButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
