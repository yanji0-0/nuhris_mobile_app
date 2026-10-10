import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nuhris_mobile_app/app_shell.dart';
import 'package:nuhris_mobile_app/providers/session_provider.dart';
import 'package:nuhris_mobile_app/providers/startup_checks_provider.dart';
import 'package:nuhris_mobile_app/screens/auth/sign_in_screen.dart';
import 'package:nuhris_mobile_app/security/device_integrity.dart';

/// Signed-out session that never touches Supabase.
class _SignedOutSession extends SessionController {
  @override
  SessionState build() =>
      const SessionState(isInitializing: false, isLoggedIn: false);
}

Widget _shell(StartupStatus status) => ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(_SignedOutSession.new),
        startupChecksProvider.overrideWith((ref) async => status),
      ],
      child: const AppShell(),
    );

void main() {
  testWidgets('Clean device shows the sign-in screen', (tester) async {
    await tester.pumpWidget(
      _shell(const StartupStatus(integrity: IntegrityReport.clean)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.text('Sign in to your account to continue'), findsOneWidget);
    // The non-functional "Remember me" option is gone; reset is real.
    expect(find.text('Remember me'), findsNothing);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('Password field disables suggestions and autocorrect',
      (tester) async {
    await tester.pumpWidget(
      _shell(const StartupStatus(integrity: IntegrityReport.clean)),
    );
    await tester.pumpAndSettle();

    final passwordFinder = find.byKey(SignInScreen.passwordFieldKey);
    TextField field() => tester.widget<TextField>(passwordFinder);
    expect(field().obscureText, isTrue);
    expect(field().enableSuggestions, isFalse);
    expect(field().autocorrect, isFalse);

    // Still off after the employee reveals the password.
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(field().obscureText, isFalse);
    expect(field().enableSuggestions, isFalse);
    expect(field().autocorrect, isFalse);
  });

  testWidgets('Tampered app is blocked before sign-in', (tester) async {
    await tester.pumpWidget(
      _shell(
        const StartupStatus(
          integrity: IntegrityReport(
            blockReason: 'This copy of NUHRIS has been modified.',
            warnings: [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NUHRIS cannot run'), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
  });

  testWidgets('Outdated version must update before sign-in', (tester) async {
    await tester.pumpWidget(
      _shell(
        const StartupStatus(
          integrity: IntegrityReport.clean,
          update: UpdateRequirement(
            message: 'Please update.',
            updateUrl: 'https://example.edu/nuhris.apk',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Update NUHRIS'), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
  });

  testWidgets('Rooted device warning must be acknowledged', (tester) async {
    await tester.pumpWidget(
      _shell(
        const StartupStatus(
          integrity: IntegrityReport(
            blockReason: null,
            warnings: ['This device appears to be rooted.'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Security warning'), findsOneWidget);
    await tester.tap(find.text('I understand, continue'));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
  });
}
