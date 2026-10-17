import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the work {'porelo-checkout-shell'} is listed
Future<void> theWorkIsListed(WidgetTester tester, String work) async {
  await toTheTile(tester, work);
  expect(find.text(work), findsOneWidget);
}
