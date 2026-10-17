import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the row of the message from {'porelo-checkout-shell'} previews {'please look'}
///
/// Empty words: it previews nothing at all.
Future<void> theRowOfTheMessageFromPreviews(WidgetTester tester, String task, String words) async {
  // The preview is read after the row is drawn.
  await World.settle(tester);
  final row = find.byWidgetPredicate(
      (each) => each is Card && '${each.key}'.contains("held-message ") && '${each.key}'.contains('/$task/'));
  final preview = find.descendant(
      of: row,
      matching: find.byWidgetPredicate(
          (each) => each.key is ValueKey<String> && (each.key! as ValueKey<String>).value.startsWith('held-preview')));
  expect(row, findsOneWidget, reason: 'the row of the message from $task');
  if (words.isEmpty) {
    expect(preview, findsNothing);
  } else {
    expect(tester.widget<Text>(preview).data, contains(words));
  }
}
