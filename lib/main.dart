import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_shell.dart';
import 'config/app_config.dart';
import 'services/secure_session_storage.dart';
import 'utils/app_log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installReleaseErrorHandlers();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      // Session tokens and the PKCE verifier live in Keystore-backed secure
      // storage instead of plaintext SharedPreferences.
      localStorage: SecureSessionStorage(
        persistSessionKey:
            'sb-${Uri.parse(AppConfig.supabaseUrl).host.split('.').first}-auth-token',
      ),
      pkceAsyncStorage: const SecureGotrueAsyncStorage(),
      // The app registers no deep links; never accept sessions from URIs.
      detectSessionInUri: false,
    ),
  );

  runApp(const ProviderScope(child: AppShell()));
}
