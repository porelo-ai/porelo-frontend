import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: no machine notice says {'cannot be reached'}
Future<void> noMachineNoticeSays(WidgetTester tester, String words) async {
  expect(
    find.descendant(
      of: find.byKey(const Key('open-attention')),
      matching: find.descendant(
        of: find.byWidgetPredicate((widget) => '${widget.key}'.contains("'machine-notice ")),
        matching: find.textContaining(words, findRichText: true),
      ),
    ),
    findsNothing,
  );
}
