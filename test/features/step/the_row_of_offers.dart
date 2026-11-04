import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the row of {'porelo-billing-shell'} offers {'Open a new terminal'}
Future<void> theRowOfOffers(WidgetTester tester, String work, String step) async {
  expect(find.descendant(of: tileFor(work), matching: find.text(step)), findsOneWidget);
}
