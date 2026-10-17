import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import 'the_test_machine_has_a_project_with_a_conversation.dart';

/// The person the scenario let in: a new name each run, since an account, once made, stays.
String? thePerson;

/// Usage: I let a person join the conversation of {'e2e-mx'} from the interface
Future<void> iLetAPersonJoinTheConversationOfFromTheInterface(WidgetTester tester, String project) async {
  await toTheMachines(tester);
  if (noConversationHere != null) return;
  await switchTo(tester, E2e.name);
  final row = find.byKey(ValueKey<String>('project $project'));
  for (var i = 0; i < 12 && row.evaluate().isEmpty; i++) {
    await showOnTheMachines(tester, row);
    await pumpFor(tester, const Duration(seconds: 5));
  }
  expect(row, findsOneWidget, reason: 'the project $project is not listed');
  await tester.ensureVisible(row);
  await tester.tap(row);
  await pumpFor(tester);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await pumpFor(tester);
  const command = 'Messages — the conversation of this project, and who has joined it';
  await tester.enterText(find.byType(TextField).last, command);
  await pumpFor(tester);
  await tester.tap(find.widgetWithText(ListTile, command).last);
  final there = find.byKey(const Key('highlighted'));
  await pumpUntil(tester, () => there.evaluate().isNotEmpty, what: 'the finder to mark the command');
  await pumpFor(tester);
  await tester.tap(there.first);
  await pumpUntilShown(tester, const Key('join-person'));
  final person = thePerson = 'e2e-${DateTime.now().millisecondsSinceEpoch}';
  await tester.enterText(find.byKey(const Key('join-person')), person);
  await pumpFor(tester);
  await tester.tap(find.byKey(const Key('join-it')));
  await pumpUntil(
    tester,
    () =>
        find.byKey(const Key('login password')).evaluate().isNotEmpty ||
        find.byKey(const Key('messages-problem')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 60),
    what: 'the machine to let $person in',
  );
  expect(find.byKey(const Key('messages-problem')), findsNothing);
}
