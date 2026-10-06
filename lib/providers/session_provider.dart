import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_client.dart';
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
  static const _privacyAckPrefsKey = 'privacy_notice_session_ack';

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
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_privacyAckPrefsKey) == key;
    } catch (error) {
      debugPrint('Privacy Notice session check failed: $error');
      return false;
    }
  }

  Future<void> _rememberLoginSessionAck() async {
    final key = _loginSessionAckKey();
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_privacyAckPrefsKey, key);
    } catch (error) {
      debugPrint('Privacy Notice session marker not saved: $error');
    }
  }

  Future<void> _forgetLoginSessionAck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_privacyAckPrefsKey);
    } catch (error) {
      debugPrint('Privacy Notice session marker not cleared: $error');
    }
  }

  Future<void> _bootstrapSession() async {
    final api = ref.read(apiClientProvider);

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
    } on ApiException catch (error) {
      return error.message;
    } catch (error) {
      return error.toString();
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

    state = state.copyWith(
      isLoggedIn: false,
      authUid: null,
      privacyAcknowledged: false,
    );

    ref.invalidate(dashboardProvider);
    ref.invalidate(accountProvider);
    ref.invalidate(profilePhotoProvider);
    ref.invalidate(
      notificationsControllerProvider,
    );
  }
}
