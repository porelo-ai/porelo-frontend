import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the work {'porelo-checkout-shell'} is no longer listed
Future<void> theWorkIsNoLongerListed(WidgetTester tester, String work) async {
  // The effect, not the report: only "it is gone" is what somebody looking can see.
  expect(tileFor(work), findsNothing);
}
