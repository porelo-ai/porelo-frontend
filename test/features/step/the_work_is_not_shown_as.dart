import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the work {'porelo-checkout-shell'} is not shown as {'idle'}
Future<void> theWorkIsNotShownAs(WidgetTester tester, String work, String words) async {
  // A state that is silently wrong is worse than one that says it does not know, so what cannot
  // be seen must not borrow the words for something that can.
  expect(whatItSaysAbout(tester, work), isNot(contains(words)));
}
