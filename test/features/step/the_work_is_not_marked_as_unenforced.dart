import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the work {'porelo-billing-shell'} is not marked as unenforced
Future<void> theWorkIsNotMarkedAsUnenforced(WidgetTester tester, String work) async {
  await toTheTile(tester, work);
  // A tile that is not there has no mark either, which would pass this for the wrong reason.
  expect(tileFor(work), findsOneWidget);
  expect(find.descendant(of: tileFor(work), matching: find.byKey(const Key('unenforced'))),
      findsNothing);
}
