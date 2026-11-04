import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the row of {'porelo-checkout-migrate'} is in the group {'reviews'}
///
/// `decide`, `reviews` or `rest`: the cards *Needs you* stands its rows in.
Future<void> theRowOfIsInTheGroup(WidgetTester tester, String work, String group) async {
  final row = find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('attention-row tile ') && key.value.endsWith('/$work');
  });
  expect(find.descendant(of: find.byKey(ValueKey<String>('needs-group $group')), matching: row), findsOneWidget);
}
