import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import 'api_client_provider.dart';

class SessionState {
  final bool isInitializing;
  final bool isLoggedIn;

  const SessionState({required this.isInitializing, required this.isLoggedIn});

  const SessionState.initial() : isInitializing = true, isLoggedIn = false;

  SessionState copyWith({bool? isInitializing, bool? isLoggedIn}) {
    return SessionState(
      isInitializing: isInitializing ?? this.isInitializing,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
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
    final allowed = await api.hasEmployeeAccess();
    state = SessionState(isInitializing: false, isLoggedIn: allowed);
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
    state = state.copyWith(isLoggedIn: false);
  }
}
