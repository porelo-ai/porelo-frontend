import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the row of {'porelo-checkout-shell'} does not offer {'See it in Needs you'}
Future<void> theRowOfDoesNotOffer(WidgetTester tester, String work, String step) async {
  expect(find.descendant(of: tileFor(work), matching: find.text(step)), findsNothing);
}
