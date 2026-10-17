import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the command {'Open the selected work'} is offered as unavailable
Future<void> theCommandIsOfferedAsUnavailable(WidgetTester tester, String command) async {
  await tester.enterText(find.byType(TextField), command);
  await World.settle(tester);

  final tile = tester.widget<ListTile>(
    find.descendant(of: find.byType(Dialog), matching: find.widgetWithText(ListTile, command)),
  );
  expect(tile.enabled, isFalse, reason: '$command should not be runnable now');
  expect((tile.subtitle! as Text).data, contains('unavailable'));
}
