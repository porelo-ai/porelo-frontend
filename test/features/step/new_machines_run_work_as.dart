import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import 'i_choose_the_command.dart';

/// Usage: new machines run work as {'builder'}
///
/// Through the options, as a person would, and then the machine dialog opened again.
Future<void> newMachinesRunWorkAs(WidgetTester tester, String user) async {
  await tester.tap(
    find.byType(CloseButton).evaluate().isEmpty
        ? find.widgetWithText(TextButton, 'Cancel').last
        : find.byType(CloseButton),
  );
  await World.settle(tester);
  await iChooseTheCommand(tester, 'New machines run work as: agent…');
  await tester.enterText(find.byKey(const Key('work-user')), user);
  await World.settle(tester);
  await tester.tap(find.byKey(const Key('work-user-save')));
  await World.settle(tester);
  await tester.tap(find.byTooltip('Watch another machine…'));
  await World.settle(tester);
}
