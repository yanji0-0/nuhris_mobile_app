import 'package:flutter/foundation.dart';

/// Diagnostic logging for development only.
///
/// `debugPrint` still writes to logcat in release builds, so every log call in
/// the app goes through here instead. In release/profile builds nothing is
/// emitted. Never pass tokens, passwords, signed URLs or employee rows; log
/// the operation and the error type/code instead.
void appLog(String message, [Object? error]) {
  if (!kDebugMode) return;
  debugPrint(error == null ? message : '$message: $error');
}

/// Keeps uncaught errors out of logcat in release/profile builds.
///
/// Flutter's default handlers print the full exception text even in release,
/// and that text can carry backend responses, signed URLs or employee data.
/// Debug builds keep the default reporting so developers still see errors.
void installReleaseErrorHandlers({bool debugMode = kDebugMode}) {
  if (debugMode) return;
  FlutterError.onError = (_) {};
  PlatformDispatcher.instance.onError = (_, _) => true;
}
