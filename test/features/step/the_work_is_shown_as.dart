import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the work {'porelo-checkout-shell'} is shown as {'waiting'}
Future<void> theWorkIsShownAs(WidgetTester tester, String work, String words) async {
  await toTheTile(tester, work);
  expect(tileFor(work), findsOneWidget);
  expect(whatItSaysAbout(tester, work), contains(words));
}
