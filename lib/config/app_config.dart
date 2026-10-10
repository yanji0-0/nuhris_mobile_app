import 'package:flutter/foundation.dart';

class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xzirvadcrgqnvrzhekmj.supabase.co',
  );

  /// Public "anon" key: it only identifies the project. Data protection must
  /// come from Supabase Row Level Security, never from keeping this secret.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6aXJ2YWRjcmdxbnZyemhla21qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5NDY0NDAsImV4cCI6MjA5MDUyMjQ0MH0.5AsrwSkQa2js6VPrupkzwsjH6jGXWEz4X0qE-rDDBbY',
  );

  /// NUHRIS Laravel web portal (Academic Calendar API, password reset page).
  /// Must be HTTPS in release builds; see [secureBaseUrl].
  static const String laravelBaseUrl = String.fromEnvironment(
    'LARAVEL_BASE_URL',
    defaultValue: '',
  );

  /// Returns the Laravel base URL without a trailing slash, or null when it is
  /// missing or not allowed. Release builds only accept https://. Debug builds
  /// may also use http:// for a local development server (the Android network
  /// security config only permits cleartext to 10.0.2.2/localhost in debug).
  static String? get secureBaseUrl =>
      validateBaseUrl(laravelBaseUrl, allowHttp: !kReleaseMode);

  @visibleForTesting
  static String? validateBaseUrl(String raw, {required bool allowHttp}) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty || uri.hasQuery || uri.hasFragment) {
      return null;
    }
    final ok = uri.isScheme('https') || (allowHttp && uri.isScheme('http'));
    if (!ok) return null;
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  /// True for an absolute https:// URL (used for links from the database).
  static bool isHttpsUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null && uri.isScheme('https') && uri.host.isNotEmpty;
  }

  /// Parses an employee-supplied external link (e.g. a WFH `monitoring_link`)
  /// for opening in the browser. Only absolute https:// URLs with a host are
  /// accepted; http://, other schemes (javascript:, intent:, file:, ...),
  /// embedded credentials and malformed values (whitespace or control
  /// characters, percent-encoded hosts, invalid ports) return null.
  static Uri? safeExternalLink(Object? raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty || value.contains(RegExp(r'[\s\x00-\x1F\x7F]'))) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.isScheme('https') ||
        uri.host.isEmpty ||
        uri.host.contains('%') ||
        uri.port < 1 ||
        uri.port > 65535 ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }
}
