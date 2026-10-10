import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/app_log.dart';

/// SHA-256 of the NUHRIS release signing certificate
/// (CN=NUHRIS Employee Mobile, android/app/nuhris-release.jks). A release APK
/// signed with any other key has been repackaged.
const String releaseSigningCertSha256 =
    '4ACC01EFDBAE57E0E28714308BE305497B0DD33CC3D1826F09FE129A2BB35D10';

class IntegrityReport {
  const IntegrityReport({
    required this.blockReason,
    required this.warnings,
  });

  /// Non-null when the app must not run (release builds only).
  final String? blockReason;

  /// Risks the employee is told about before continuing.
  final List<String> warnings;

  static const clean = IntegrityReport(blockReason: null, warnings: []);
}

/// Applies the NUHRIS response policy to the native checks in
/// `DeviceIntegrity.kt`:
/// * block: modified/re-signed APK, debuggable build, debugger attached,
///   Frida/Xposed hooking (release builds);
/// * warn: rooted device or emulator (the employee may continue, because the
///   backend still enforces access control and blocking would lock out staff).
@visibleForTesting
IntegrityReport evaluateIntegrity(
  Map<String, dynamic> raw, {
  required bool enforce,
}) {
  String? block;
  if (enforce) {
    final cert = (raw['signingCertSha256'] ?? '').toString().toUpperCase();
    if (cert != releaseSigningCertSha256) {
      block = 'This copy of NUHRIS has been modified or was not signed by '
          'National University. Please install the official app.';
    } else if (raw['debuggable'] == true || raw['debuggerAttached'] == true) {
      block = 'A debugger is attached to NUHRIS. Close debugging tools and '
          'reopen the app.';
    } else if (raw['hookingDetected'] == true) {
      block = 'Instrumentation or hooking tools were detected on this device. '
          'Remove them and reopen NUHRIS.';
    }
  }

  return IntegrityReport(
    blockReason: block,
    warnings: [
      if (raw['rooted'] == true)
        'This device appears to be rooted. Other apps may be able to read '
            'the HR information NUHRIS displays.',
      if (raw['emulator'] == true)
        'NUHRIS is running on an emulator rather than a physical device.',
    ],
  );
}

class DeviceIntegrity {
  static const _channel = MethodChannel('nuhris/security');

  /// Runs the native checks. Enforcement only applies to Android release
  /// builds; if the checks cannot run there, the app fails closed.
  static Future<IntegrityReport> inspect() async {
    final enforce =
        kReleaseMode && defaultTargetPlatform == TargetPlatform.android;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return IntegrityReport.clean;
    }
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('inspect');
      return evaluateIntegrity(raw ?? const {}, enforce: enforce);
    } catch (error) {
      appLog('Integrity check failed', error.runtimeType);
      if (!enforce) return IntegrityReport.clean;
      return const IntegrityReport(
        blockReason: 'NUHRIS could not verify the integrity of this app. '
            'Please reinstall the official app.',
        warnings: [],
      );
    }
  }
}
