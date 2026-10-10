import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nuhris_mobile_app/config/app_config.dart';
import 'package:nuhris_mobile_app/theme/app_theme.dart';
import 'package:nuhris_mobile_app/widgets/nuhris_website_card.dart';

Widget _host(Future<bool> Function(Uri) openUrl) => MaterialApp(
      home: Scaffold(body: NuhrisWebsiteCard(openUrl: openUrl)),
    );

void main() {
  test('website address is the official HTTPS site', () {
    expect(NuhrisWebsiteCard.websiteUri.toString(), 'https://nuhris.com/');
    expect(AppConfig.safeExternalLink('https://nuhris.com/'), isNotNull);
  });

  testWidgets('button uses the NUHRIS navy and opens https://nuhris.com/',
      (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(_host((uri) async {
      opened.add(uri);
      return true;
    }));

    expect(find.text('Open NUHRIS Website'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(NuhrisWebsiteCard.buttonKey),
    );
    expect(
      button.style!.backgroundColor!.resolve(<WidgetState>{}),
      AppColors.appBarNavy,
    );
    expect(AppColors.appBarNavy, const Color(0xFF0A1B66));

    await tester.tap(find.byKey(NuhrisWebsiteCard.buttonKey));
    await tester.pump();

    expect(opened, [Uri.parse('https://nuhris.com/')]);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('shows a message when no browser can open the site',
      (tester) async {
    await tester.pumpWidget(_host((uri) async => false));
    await tester.tap(find.byKey(NuhrisWebsiteCard.buttonKey));
    await tester.pump();

    expect(
      find.text('Unable to open the NUHRIS website. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('does not crash when launching throws', (tester) async {
    await tester.pumpWidget(_host((uri) async => throw Exception('no activity')));
    await tester.tap(find.byKey(NuhrisWebsiteCard.buttonKey));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Unable to open the NUHRIS website. Please try again.'),
      findsOneWidget,
    );
  });
}
