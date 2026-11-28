import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/held_saves.dart';

/// Usage: the held save of {'cart-move'} shows its change, the forges answer and its tries
Future<void> theHeldSaveOfShowsItsChangeTheForgesAnswerAndItsTries(WidgetTester tester, String story) async {
  final id = heldSaveId(story);
  final details = find.byKey(Key('held-save-details $id'));
  expect(details, findsOneWidget);
  Finder inIt(Finder what) => find.descendant(of: details, matching: what);
  // The change is one row of its table: the field, what GitHub holds now, and the save's own value.
  expect(inIt(find.byKey(Key('held-save-field $id 0'))), findsOneWidget);
  expect(tester.widget<Text>(inIt(find.byKey(Key('held-save-before $id 0')))).data, contains('Backlog'));
  expect(tester.widget<Text>(inIt(find.byKey(Key('held-save-after $id 0')))).data, 'In analysis');
  expect(inIt(find.byKey(Key('held-save-answer $id'))), findsOneWidget);
  expect(inIt(find.textContaining('HTTP 502 · Bad gateway')), findsWidgets);
  expect(inIt(find.textContaining(heldRequestId)), findsWidgets);
  expect(inIt(find.byKey(Key('held-save-try $id 0'))), findsOneWidget);
  expect(inIt(find.byKey(Key('held-save-try $id 1'))), findsOneWidget);
}
