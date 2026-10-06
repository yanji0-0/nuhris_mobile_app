import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/session_provider.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/privacy_notice_screen.dart';
import 'theme/app_theme.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final controller = ref.read(sessionControllerProvider.notifier);

    if (session.isInitializing) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (!session.isLoggedIn) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SignInScreen(
          onSignIn: controller.signIn,
          authUid: session.authUid,
        ),
      );
    }

    // Successful login → Privacy Notice → Continue → normal app (as on web).
    if (!session.privacyAcknowledged) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: PrivacyNoticeScreen(
          version: privacyNoticeVersion,
          onContinue: controller.acknowledgePrivacyNotice,
          onLogout: controller.signOut,
        ),
      );
    }

    return NuhrisEmployeeApp(onSignOut: controller.signOut);
  }
}
