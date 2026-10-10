import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_client.dart';
import '../utils/app_log.dart';
import 'account_provider.dart';
import 'api_client_provider.dart';
import 'dashboard_provider.dart';
import 'notifications_provider.dart';

/// Current Privacy Notice version (web `config/privacy.php` notice_version).
const privacyNoticeVersion = '1.1';

class SessionState {
  final bool isInitializing;
  final bool isLoggedIn;
  final String? authUid;

  /// Whether the Privacy Notice was accepted during the CURRENT login session
  /// (web: per-session `privacy_notice_acknowledged_version`). False after
  /// every successful sign-in and on sign-out. An existing
  /// `privacy_notice_acknowledgments` row never skips it.
  final bool privacyAcknowledged;

  const SessionState({
    required this.isInitializing,
    required this.isLoggedIn,
    this.authUid,
    this.privacyAcknowledged = false,
  });

  const SessionState.initial()
      : isInitializing = true,
        isLoggedIn = false,
        authUid = null,
        privacyAcknowledged = false;

  SessionState copyWith({
    bool? isInitializing,
    bool? isLoggedIn,
    String? authUid,
    bool? privacyAcknowledged,
  }) {
    return SessionState(
      isInitializing:
          isInitializing ?? this.isInitializing,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      authUid: authUid ?? this.authUid,
      privacyAcknowledged:
          privacyAcknowledged ?? this.privacyAcknowledged,
    );
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

class SessionController
    extends Notifier<SessionState> {
  /// Device-local marker: "this login session accepted this version".
  /// Kept in secure storage because it contains the Supabase user id.
  static const _privacyAckPrefsKey = 'privacy_notice_session_ack';
  static const _secureStorage = FlutterSecureStorage();

  /// Inactivity timeout: a session left in the background longer than this
  /// is signed out and the employee must log in again.
  static const idleTimeout = Duration(minutes: 15);
  static const _backgroundedAtKey = 'session_backgrounded_at';

  @override
  SessionState build() {
    _bootstrapSession();
    return const SessionState.initial();
  }

  /// Identifies the current login session: the Supabase user plus the time of
  /// this sign-in (it changes on every new login, not on token refresh) and
  /// the notice version. Null when there is no Supabase Auth session.
  String? _loginSessionAckKey() {
    final user = Supabase.instance.client.auth.currentUser;
    final signedInAt = user?.lastSignInAt;
    if (user == null || signedInAt == null || signedInAt.isEmpty) {
      return null;
    }
    return '${user.id}|$signedInAt|$privacyNoticeVersion';
  }

  /// Web keeps the acknowledgment in the login session; on mobile the saved
  /// login survives app restarts, so remember it on-device for that same
  /// session only. Fails closed (shows the notice) on any problem.
  Future<bool> _acknowledgedThisLoginSession() async {
    final key = _loginSessionAckKey();
    if (key == null) return false;
    try {
      return await _secureStorage.read(key: _privacyAckPrefsKey) == key;
    } catch (error) {
      appLog('Privacy Notice session check failed', error.runtimeType);
      return false;
    }
  }

  Future<void> _rememberLoginSessionAck() async {
    final key = _loginSessionAckKey();
    if (key == null) return;
    try {
      await _secureStorage.write(key: _privacyAckPrefsKey, value: key);
    } catch (error) {
      appLog('Privacy Notice session marker not saved', error.runtimeType);
    }
  }

  Future<void> _forgetLoginSessionAck() async {
    try {
      await _secureStorage.delete(key: _privacyAckPrefsKey);
      // Remove the plaintext copy written by earlier app versions.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_privacyAckPrefsKey);
    } catch (error) {
      appLog('Privacy Notice session marker not cleared', error.runtimeType);
    }
  }

  /// Called when the app goes to the background. Persisted so the timeout
  /// also applies if Android kills the app while it is in the background.
  Future<void> markBackgrounded() async {
    if (!state.isLoggedIn) return;
    try {
      await _secureStorage.write(
        key: _backgroundedAtKey,
        value: DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (error) {
      appLog('Background timestamp not saved', error.runtimeType);
    }
  }

  /// True when the app was in the background for at least [idleTimeout].
  /// Clears the marker either way.
  Future<bool> _consumeIdleExpiry() async {
    try {
      final raw = await _secureStorage.read(key: _backgroundedAtKey);
      await _secureStorage.delete(key: _backgroundedAtKey);
      final since = int.tryParse(raw ?? '');
      if (since == null) return false;
      final away = DateTime.now().millisecondsSinceEpoch - since;
      return away < 0 || away >= idleTimeout.inMilliseconds;
    } catch (error) {
      appLog('Idle check failed', error.runtimeType);
      return false;
    }
  }

  /// Called when the app returns to the foreground. Signs out an idle
  /// session and returns true if it did.
  Future<bool> signOutIfIdle() async {
    if (!await _consumeIdleExpiry() || !state.isLoggedIn) return false;
    await signOut();
    return true;
  }

  Future<void> _bootstrapSession() async {
    final api = ref.read(apiClientProvider);

    // A saved login that sat idle past the timeout must sign in again.
    if (await _consumeIdleExpiry()) {
      await api.logout();
      await _forgetLoginSessionAck();
    }

    try {
      final allowed = await api.hasEmployeeAccess();

      state = SessionState(
        isInitializing: false,
        isLoggedIn: allowed,
        authUid:
            Supabase.instance.client.auth.currentUser?.id,
        // App reopened with a saved login: only skip the notice if it was
        // already accepted during this same login session.
        privacyAcknowledged:
            allowed && await _acknowledgedThisLoginSession(),
      );
    } catch (_) {
      state = SessionState(
        isInitializing: false,
        isLoggedIn: false,
        authUid:
            Supabase.instance.client.auth.currentUser?.id,
      );
    }
  }

  Future<String?> signIn(
    String email,
    String password,
  ) async {
    final api = ref.read(apiClientProvider);

    try {
      await api.login(
        email: email,
        password: password,
      );

      final allowed =
          await api.hasEmployeeAccess();

      if (!allowed) {
        state = state.copyWith(
          isLoggedIn: false,
        );

        return 'Your account is not allowed to access the employee app.';
      }

      // Like the web: every successful login must pass the Privacy Notice,
      // even if an acknowledgment record already exists.
      await _forgetLoginSessionAck();

      state = state.copyWith(
        isLoggedIn: true,
        authUid:
            Supabase.instance.client.auth.currentUser?.id,
        privacyAcknowledged: false,
      );

      ref.invalidate(dashboardProvider);
      ref.invalidate(accountProvider);
      ref.invalidate(profilePhotoProvider);
      ref.invalidate(
        notificationsControllerProvider,
      );

      return null;
    } catch (error) {
      return userMessageFor(
        error,
        fallback: 'Unable to sign in right now. Please try again.',
      );
    }
  }

  /// Records the acknowledgment like the web, then lets the employee in.
  /// Throws if the record cannot be saved, so the gate stays closed.
  Future<void> acknowledgePrivacyNotice() async {
    await ref
        .read(apiClientProvider)
        .acknowledgePrivacyNotice(version: privacyNoticeVersion);
    await _rememberLoginSessionAck();
    state = state.copyWith(privacyAcknowledged: true);
  }

  Future<void> signOut() async {
    final api = ref.read(apiClientProvider);

    await api.logout();
    await _forgetLoginSessionAck();

    // A fresh state (copyWith cannot clear authUid back to null).
    state = const SessionState(isInitializing: false, isLoggedIn: false);

    ref.invalidate(dashboardProvider);
    ref.invalidate(accountProvider);
    ref.invalidate(profilePhotoProvider);
    ref.invalidate(
      notificationsControllerProvider,
    );
  }
}
