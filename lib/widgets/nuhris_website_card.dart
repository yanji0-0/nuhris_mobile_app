import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../utils/app_log.dart';

/// Profile section with a button that opens the official NUHRIS website in
/// the device's external browser.
class NuhrisWebsiteCard extends StatelessWidget {
  const NuhrisWebsiteCard({super.key, this.openUrl = _openExternally});

  static final Uri websiteUri = Uri.parse('https://nuhris.com/');

  @visibleForTesting
  static const buttonKey = Key('open-nuhris-website');

  /// Opens [Uri] and reports whether it worked; replaceable in tests.
  final Future<bool> Function(Uri uri) openUrl;

  static Future<bool> _openExternally(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<void> _openWebsite(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await openUrl(websiteUri);
    } catch (error) {
      appLog('NUHRIS website failed to open', error.runtimeType);
    }

    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Unable to open the NUHRIS website. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NUHRIS Website',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Visit the official NUHRIS website in your browser.',
              style: TextStyle(color: AppColors.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: buttonKey,
                onPressed: () => _openWebsite(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.appBarNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open NUHRIS Website'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
