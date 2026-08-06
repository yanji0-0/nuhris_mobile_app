import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_client.dart';
import 'account_provider.dart';
import 'api_client_provider.dart';
import 'dashboard_provider.dart';
import 'notifications_provider.dart';

class SessionState {
  final bool isInitializing;
  final bool isLoggedIn;
  final String? authUid;

  const SessionState({
    required this.isInitializing,
    required this.isLoggedIn,
    this.authUid,
  });

  const SessionState.initial()
      : isInitializing = true,
        isLoggedIn = false,
        authUid = null;

  SessionState copyWith({
    bool? isInitializing,
    bool? isLoggedIn,
    String? authUid,
  }) {
    return SessionState(
      isInitializing: isInitializing ?? this.isInitializing,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      authUid: authUid ?? this.authUid,
    );
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    _bootstrapSession();
    return const SessionState.initial();
  }

  Future<void> _bootstrapSession() async {
    final api = ref.read(apiClientProvider);
    try {
      final allowed = await api.hasEmployeeAccess();
      state = SessionState(
        isInitializing: false,
        isLoggedIn: allowed,
        authUid: Supabase.instance.client.auth.currentUser?.id,
      );
    } catch (_) {
      state = SessionState(
        isInitializing: false,
        isLoggedIn: false,
        authUid: Supabase.instance.client.auth.currentUser?.id,
      );
    }
  }

  Future<String?> signIn(String email, String password) async {
    final api = ref.read(apiClientProvider);

    try {
      await api.login(email: email, password: password);
      final allowed = await api.hasEmployeeAccess();
      if (!allowed) {
        state = state.copyWith(isLoggedIn: false);
        return 'Your account is not allowed to access the employee app.';
      }

      state = state.copyWith(isLoggedIn: true);
      state = state.copyWith(
        authUid: Supabase.instance.client.auth.currentUser?.id,
      );

      // Invalidate cached data from previous user to ensure fresh data for new login
      ref.invalidate(dashboardProvider);
      ref.invalidate(accountProvider);
      ref.invalidate(profilePhotoProvider);
      ref.invalidate(notificationsControllerProvider);

      return null;
    } on ApiException catch (error) {
      return error.message;
    } catch (error) {
      return error.toString();
    }
  }

  Future<void> signOut() async {
    final api = ref.read(apiClientProvider);
    await api.logout();
    state = state.copyWith(isLoggedIn: false, authUid: null);

    // Invalidate all user-specific providers to clear cached data
    ref.invalidate(dashboardProvider);
    ref.invalidate(accountProvider);
    ref.invalidate(profilePhotoProvider);
    ref.invalidate(notificationsControllerProvider);
  }
}
