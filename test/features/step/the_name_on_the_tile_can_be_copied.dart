import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the name on the tile {'porelo-checkout-shell'} can be copied
Future<void> theNameOnTheTileCanBeCopied(WidgetTester tester, String work) async {
  await toTheTile(tester, work);
  expect(
    find.descendant(
      of: tileFor(work),
      matching: find.byWidgetPredicate((widget) => widget is SelectableText && widget.data == work),
    ),
    findsOneWidget,
  );
}
