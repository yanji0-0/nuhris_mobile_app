import 'dart:math';
import 'dart:ui' show ErrorCallback;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nuhris_mobile_app/config/app_config.dart';
import 'package:nuhris_mobile_app/providers/startup_checks_provider.dart';
import 'package:nuhris_mobile_app/security/device_integrity.dart';
import 'package:nuhris_mobile_app/services/api_client.dart';
import 'package:nuhris_mobile_app/utils/app_log.dart';
import 'package:nuhris_mobile_app/utils/upload_validation.dart';

Uint8List _bytes(List<int> header, [int size = 64]) =>
    Uint8List(size)..setAll(0, header);

final _pdf = [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x37];
final _png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
final _jpg = [0xFF, 0xD8, 0xFF, 0xE0];

void main() {
  group('Upload validation', () {
    test('accepts PDF/PNG/JPG whose content matches the extension', () {
      expect(validateUpload(originalName: 'a.pdf', bytes: _bytes(_pdf))
          .contentType, 'application/pdf');
      expect(validateUpload(originalName: 'a.PNG', bytes: _bytes(_png))
          .contentType, 'image/png');
      expect(validateUpload(originalName: 'a.jpeg', bytes: _bytes(_jpg))
          .extension, 'jpg');
    });

    test('rejects disallowed extensions', () {
      expect(
        () => validateUpload(originalName: 'run.exe', bytes: _bytes(_pdf)),
        throwsA(isA<UploadValidationException>()),
      );
      expect(
        () => validateUpload(originalName: 'page.html', bytes: _bytes(_pdf)),
        throwsA(isA<UploadValidationException>()),
      );
    });

    test('rejects content that does not match the extension', () {
      // An HTML/script payload renamed to .pdf.
      final html = Uint8List.fromList('<html><script>'.codeUnits);
      expect(
        () => validateUpload(originalName: 'cv.pdf', bytes: html),
        throwsA(isA<UploadValidationException>()),
      );
      expect(
        () => validateUpload(originalName: 'photo.png', bytes: _bytes(_pdf)),
        throwsA(isA<UploadValidationException>()),
      );
    });

    test('rejects empty and oversized files', () {
      expect(
        () => validateUpload(originalName: 'a.pdf', bytes: Uint8List(0)),
        throwsA(isA<UploadValidationException>()),
      );
      expect(
        () => validateUpload(
          originalName: 'a.pdf',
          bytes: _bytes(_pdf, maxUploadBytes + 1),
        ),
        throwsA(isA<UploadValidationException>()),
      );
    });

    test('stores under a random server-style name, never the user name', () {
      final result = validateUpload(
        originalName: '../../etc/pass wd;rm -rf.pdf',
        bytes: _bytes(_pdf),
        random: Random(1),
        now: DateTime.fromMillisecondsSinceEpoch(1755712345000),
      );
      expect(result.storedFileName, matches(RegExp(r'^1755712345_[0-9a-f]{8}\.pdf$')));
      expect(result.displayFileName, isNot(contains('/')));
      expect(result.displayFileName, isNot(contains(' ')));
    });
  });

  group('HTTPS enforcement', () {
    test('release builds reject http:// base URLs', () {
      expect(
        AppConfig.validateBaseUrl('http://192.168.254.101:8000', allowHttp: false),
        isNull,
      );
      expect(
        AppConfig.validateBaseUrl('https://hris.example.edu/', allowHttp: false),
        'https://hris.example.edu',
      );
    });

    test('debug builds may use a local http:// server', () {
      expect(
        AppConfig.validateBaseUrl('http://10.0.2.2:8000', allowHttp: true),
        'http://10.0.2.2:8000',
      );
    });

    test('rejects other schemes and malformed URLs', () {
      for (final bad in ['ftp://x', 'javascript:alert(1)', 'hris', '']) {
        expect(AppConfig.validateBaseUrl(bad, allowHttp: true), isNull);
      }
      expect(AppConfig.isHttpsUrl('http://x.supabase.co/f.pdf'), isFalse);
      expect(AppConfig.isHttpsUrl('https://x.supabase.co/f.pdf'), isTrue);
    });
  });

  group('WFH monitoring links', () {
    test('accepts absolute https:// links', () {
      for (final good in [
        'https://drive.google.com/file/d/abc/view?usp=sharing',
        '  https://hris.example.edu/monitoring#day-1  ',
        'HTTPS://Example.com/path',
      ]) {
        final uri = AppConfig.safeExternalLink(good);
        expect(uri, isNotNull, reason: good);
        expect(uri!.scheme, 'https');
      }
    });

    test('rejects http:// links', () {
      expect(AppConfig.safeExternalLink('http://drive.google.com/x'), isNull);
      expect(AppConfig.safeExternalLink('HTTP://example.com'), isNull);
    });

    test('rejects malformed and empty links', () {
      for (final bad in [
        null,
        '',
        '   ',
        'drive.google.com/file',
        'https://',
        'https:///no-host',
        'https://exa mple.com/',
        'https://[::1/x',
        'https://user:pass@example.com/x',
        'https://good.com@evil.com',
        'https://exa\u0000mple.com',
        'https://example.com/\u0007',
        'https://exa%00mple.com',
        'https://example.com:99999/',
        'https://example.com:0/',
      ]) {
        expect(AppConfig.safeExternalLink(bad), isNull, reason: '$bad');
      }
    });

    test('rejects unsupported schemes', () {
      for (final bad in [
        'javascript:alert(1)',
        'file:///data/data/com.example.nuhris_mobile_app/x',
        'intent://scan/#Intent;scheme=zxing;end',
        'content://media/external/file/1',
        'ftp://example.com/x',
        'mailto:hr@example.edu',
        'tel:+6300000000',
        'data:text/html,<script>alert(1)</script>',
      ]) {
        expect(AppConfig.safeExternalLink(bad), isNull, reason: bad);
      }
    });
  });

  group('Release error handlers', () {
    late FlutterExceptionHandler? savedFlutterOnError;
    late ErrorCallback? savedPlatformOnError;
    late DebugPrintCallback savedDebugPrint;

    setUp(() {
      savedFlutterOnError = FlutterError.onError;
      savedPlatformOnError = PlatformDispatcher.instance.onError;
      savedDebugPrint = debugPrint;
    });

    tearDown(() {
      FlutterError.onError = savedFlutterOnError;
      PlatformDispatcher.instance.onError = savedPlatformOnError;
      debugPrint = savedDebugPrint;
    });

    test('release builds report nothing for uncaught errors', () {
      final printed = <String?>[];
      debugPrint = (message, {wrapWidth}) => printed.add(message);

      installReleaseErrorHandlers(debugMode: false);
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: Exception(
            'PostgrestException: row employee_id=12 '
            'credentials/employee-12/x.pdf?token=secret',
          ),
        ),
      );
      final handled = PlatformDispatcher.instance.onError!(
        Exception('access_token=secret'),
        StackTrace.empty,
      );

      expect(printed, isEmpty);
      expect(handled, isTrue);
    });

    test('debug builds keep the default handlers', () {
      installReleaseErrorHandlers(debugMode: true);
      expect(FlutterError.onError, same(savedFlutterOnError));
      expect(PlatformDispatcher.instance.onError, same(savedPlatformOnError));
    });
  });

  group('Integrity policy', () {
    final clean = {
      'rooted': false,
      'emulator': false,
      'debuggable': false,
      'debuggerAttached': false,
      'hookingDetected': false,
      'signingCertSha256': releaseSigningCertSha256,
    };

    test('official release on a clean device passes', () {
      final r = evaluateIntegrity(clean, enforce: true);
      expect(r.blockReason, isNull);
      expect(r.warnings, isEmpty);
    });

    test('re-signed (tampered) APK is blocked', () {
      final r = evaluateIntegrity(
        {...clean, 'signingCertSha256': '08748AC9494B5A42'},
        enforce: true,
      );
      expect(r.blockReason, isNotNull);
    });

    test('debugger and hooking frameworks are blocked', () {
      expect(
        evaluateIntegrity({...clean, 'debuggerAttached': true}, enforce: true)
            .blockReason,
        isNotNull,
      );
      expect(
        evaluateIntegrity({...clean, 'hookingDetected': true}, enforce: true)
            .blockReason,
        isNotNull,
      );
    });

    test('rooted device and emulator produce warnings', () {
      final r = evaluateIntegrity(
        {...clean, 'rooted': true, 'emulator': true},
        enforce: true,
      );
      expect(r.blockReason, isNull);
      expect(r.warnings, hasLength(2));
    });

    test('debug builds are not blocked', () {
      final r = evaluateIntegrity(
        {...clean, 'signingCertSha256': 'DEBUG', 'debuggable': true},
        enforce: false,
      );
      expect(r.blockReason, isNull);
    });
  });

  group('Minimum version policy', () {
    test('no policy configured means no enforcement', () {
      expect(evaluateVersionPolicy(installedBuild: 1, policy: null), isNull);
    });

    test('older build must update; current build passes', () {
      final policy = {
        'min_version_code': 2,
        'update_url': 'https://hris.example.edu/app',
      };
      final required =
          evaluateVersionPolicy(installedBuild: 1, policy: policy);
      expect(required, isNotNull);
      expect(required!.updateUrl, 'https://hris.example.edu/app');
      expect(evaluateVersionPolicy(installedBuild: 2, policy: policy), isNull);
    });

    test('non-HTTPS update links are not offered', () {
      final required = evaluateVersionPolicy(
        installedBuild: 1,
        policy: {'min_version_code': 5, 'update_url': 'http://evil.test/a.apk'},
      );
      expect(required!.updateUrl, isNull);
    });
  });

  group('User-facing errors', () {
    test('internal errors are replaced with a generic message', () {
      final message = userMessageFor(
        Exception('PostgrestException(message: permission denied for table '
            'employees, code: 42501) bucket credentials/employee-12/x.pdf'),
      );
      expect(message, isNot(contains('employees')));
      expect(message, isNot(contains('credentials')));
    });

    test('safe API messages are shown as-is', () {
      expect(
        userMessageFor(ApiException('Unable to load your leave records.')),
        'Unable to load your leave records.',
      );
    });
  });
}
