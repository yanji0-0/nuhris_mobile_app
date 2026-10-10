import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/session_provider.dart';
import 'providers/startup_checks_provider.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/privacy_notice_screen.dart';
import 'screens/startup_gate_screen.dart';
import 'theme/app_theme.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(startupChecksProvider);
    final session = ref.watch(sessionControllerProvider);
    final controller = ref.read(sessionControllerProvider.notifier);

    Widget gate(Widget screen) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: screen,
        );

    final status = startup.valueOrNull;
    if (status == null || session.isInitializing) {
      return gate(
        const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // Integrity and minimum-version checks run before anything else.
    final blockReason = status.integrity.blockReason;
    if (blockReason != null) {
      return gate(
        StartupGateScreen(
          icon: Icons.gpp_bad_outlined,
          title: 'NUHRIS cannot run',
          messages: [blockReason],
        ),
      );
    }

    final update = status.update;
    if (update != null) {
      final url = update.updateUrl;
      return gate(
        StartupGateScreen(
          icon: Icons.system_update_outlined,
          title: 'Update required',
          messages: [update.message],
          actionLabel: url == null ? null : 'Update NUHRIS',
          onAction:
              url == null ? null : () => StartupGateScreen.openUpdateUrl(url),
        ),
      );
    }

    final warnings = status.integrity.warnings;
    if (warnings.isNotEmpty && !ref.watch(integrityWarningAcceptedProvider)) {
      return gate(
        StartupGateScreen(
          icon: Icons.warning_amber_rounded,
          title: 'Security warning',
          messages: warnings,
          actionLabel: 'I understand, continue',
          onAction: () =>
              ref.read(integrityWarningAcceptedProvider.notifier).state = true,
        ),
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
      return gate(
        PrivacyNoticeScreen(
          version: privacyNoticeVersion,
          onContinue: controller.acknowledgePrivacyNotice,
          onLogout: controller.signOut,
        ),
      );
    }

    return NuhrisEmployeeApp(onSignOut: controller.signOut);
  }
}
