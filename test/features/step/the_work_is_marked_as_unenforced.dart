import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the work {'porelo-billing-audit'} is marked as unenforced
Future<void> theWorkIsMarkedAsUnenforced(WidgetTester tester, String work) async {
  await toTheTile(tester, work);
  // Wherever the work appears: nothing will ever be asked about what it reaches, by choice.
  expect(
    find.descendant(of: tileFor(work), matching: find.byKey(const Key('unenforced'))),
    findsOneWidget,
    reason: '$work should be marked: ${whatItSaysAbout(tester, work)}',
  );
}
