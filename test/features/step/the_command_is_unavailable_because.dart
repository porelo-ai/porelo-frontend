import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the command {'Work in it by hand'} is unavailable because {'This is not running'}
///
/// **Which reason, not merely that there is one.** Two different things can take the same action
/// away, and a scenario that only asked whether it was offered would pass on the wrong one —
/// which is exactly what a mutation of the running check proved here.
Future<void> theCommandIsUnavailableBecause(WidgetTester tester, String command, String because) async {
  await tester.enterText(find.byKey(const Key('command-query')), command);
  await World.settle(tester);

  final tile = tester.widget<ListTile>(
    find.descendant(of: find.byType(Dialog), matching: find.widgetWithText(ListTile, command)),
  );
  expect(tile.enabled, isFalse, reason: '$command should not be runnable now');
  expect((tile.subtitle! as Text).data, contains(because));
}
