import 'package:flutter_test/flutter_test.dart';

import 'package:nuhris_mobile_app/app.dart';

void main() {
  testWidgets('App loads dashboard screen', (WidgetTester tester) async {
    await tester.pumpWidget(NuhrisEmployeeApp(onSignOut: () {}));

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Welcome back, Ian!'), findsOneWidget);
  });
}
