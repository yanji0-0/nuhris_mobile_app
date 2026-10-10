import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_config.dart';
import '../security/device_integrity.dart';
import '../utils/app_log.dart';
import 'api_client_provider.dart';

class UpdateRequirement {
  const UpdateRequirement({required this.message, this.updateUrl});

  final String message;

  /// HTTPS download/store page, or null if none is configured.
  final String? updateUrl;
}

class StartupStatus {
  const StartupStatus({required this.integrity, this.update});

  final IntegrityReport integrity;
  final UpdateRequirement? update;
}

/// Compares the installed build number with the policy row in
/// `mobile_app_versions`. No row (or unreadable policy) means no enforcement.
@visibleForTesting
UpdateRequirement? evaluateVersionPolicy({
  required int installedBuild,
  required Map<String, dynamic>? policy,
}) {
  if (policy == null) return null;
  final minBuild = int.tryParse('${policy['min_version_code'] ?? ''}');
  if (minBuild == null || installedBuild >= minBuild) return null;

  final url = (policy['update_url'] ?? '').toString().trim();
  final custom = (policy['message'] ?? '').toString().trim();
  final latest = (policy['latest_version_name'] ?? '').toString().trim();
  return UpdateRequirement(
    message: custom.isNotEmpty
        ? custom
        : 'This version of NUHRIS is no longer supported. Please install '
            '${latest.isNotEmpty ? 'version $latest' : 'the latest version'} '
            'to continue.',
    updateUrl: AppConfig.isHttpsUrl(url) ? url : null,
  );
}

/// Integrity and minimum-version checks, run once before sign-in.
final startupChecksProvider = FutureProvider<StartupStatus>((ref) async {
  final integrity = await DeviceIntegrity.inspect();
  if (integrity.blockReason != null) {
    return StartupStatus(integrity: integrity);
  }

  UpdateRequirement? update;
  try {
    final info = await PackageInfo.fromPlatform();
    final installed = int.tryParse(info.buildNumber) ?? 0;
    final policy = await ref.read(apiClientProvider).getMobileVersionPolicy();
    update = evaluateVersionPolicy(installedBuild: installed, policy: policy);
  } catch (error) {
    appLog('Version check failed', error.runtimeType);
  }
  return StartupStatus(integrity: integrity, update: update);
});

/// Whether the employee accepted the rooted/emulator warning this launch.
final integrityWarningAcceptedProvider = StateProvider<bool>((_) => false);
