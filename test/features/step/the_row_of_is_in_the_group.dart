import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the row of {'porelo-checkout-migrate'} is in the group {'reviews'}
///
/// `decide`, `reviews` or `rest`: the cards *Needs you* stands its rows in. Each cause of the work is a row of its
/// own; the one meant is the one the work has in that group.
Future<void> theRowOfIsInTheGroup(WidgetTester tester, String work, String group) async {
  expect(
    find.descendant(of: find.byKey(ValueKey<String>('needs-group $group')), matching: causeRows(work)),
    findsOneWidget,
  );
}
