import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nuhris_mobile_app/navigation/app_nav.dart';
import 'package:nuhris_mobile_app/providers/account_provider.dart';
import 'package:nuhris_mobile_app/theme/app_theme.dart';
import 'package:nuhris_mobile_app/widgets/app_drawer.dart';

Widget _drawer(Future<Map<String, dynamic>> Function() account) =>
    ProviderScope(
      overrides: [
        accountProvider.overrideWith((ref) => account()),
        profilePhotoProvider.overrideWith((ref) async => null),
        appVersionProvider.overrideWith((ref) async => '1.1.0'),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: AppDrawer(selected: AppNavItem.dashboard, onSelect: (_) {}),
        ),
      ),
    );

/// Loads the bundled Inter font so layout is measured with the real font
/// (the default test font draws every glyph as a full-width square).
Future<void> _loadInter() async {
  final loader = FontLoader('Inter');
  for (final w in [
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
    'Black',
  ]) {
    final bytes = File('assets/fonts/inter/Inter-$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  setUpAll(_loadInter);

  testWidgets(
    'footer shows the installed app version; no Privacy Notice item',
    (tester) async {
      await tester.pumpWidget(
        _drawer(
          () async => {
            'user': {'name': 'Ana', 'email': 'a@nu.edu.ph'},
            'employee': {'first_name': 'Ana', 'last_name': 'Cruz'},
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HRIS · v1.1.0'), findsOneWidget);
      expect(find.text('HRIS · v1.0'), findsNothing);
      expect(find.text('Privacy Notice'), findsNothing);
    },
  );

  testWidgets('account load failure shows a safe message, not the raw error', (
    tester,
  ) async {
    await tester.pumpWidget(
      _drawer(
        () async => throw Exception(
          'PostgrestException(permission denied for table employees, code 42501)',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to load your account. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('PostgrestException'), findsNothing);
    expect(find.textContaining('employees'), findsNothing);
  });
}
