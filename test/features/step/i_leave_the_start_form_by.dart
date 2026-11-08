import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I leave the start form by {'Escape'}
///
/// `Escape`, `the barrier` (a press outside the form) or `Not now`.
Future<void> iLeaveTheStartFormBy(WidgetTester tester, String how) async {
  switch (how) {
    case 'Escape':
      // From inside the form, where a person's keyboard is.
      await tester.tap(find.byKey(const Key('start-name')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    case 'the barrier':
      await tester.tapAt(const Offset(4, 4));
    default:
      await tester.tap(find.byKey(const Key('start-not-now')));
  }
  await World.settle(tester);
  expect(find.byKey(const Key('start-go')), findsNothing, reason: 'the form must be gone');
}
