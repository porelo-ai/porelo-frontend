import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the Start work dialog says of a task while it waits on the window's Start.
const startWaitWords = 'Waiting for Start; the window shows how far it is.';

/// Usage: the Start work dialog waits on Start with its mark
Future<void> theStartWorkDialogWaitsOnStartWithItsMark(WidgetTester tester) async {
  final words = find.text(startWaitWords);
  expect(words, findsWidgets, reason: 'the dialog says that it waits on Start, and where its progress shows');
  final beside = find.ancestor(of: words.first, matching: find.byType(Row)).first;
  expect(
    find.descendant(of: beside, matching: find.byIcon(Icons.hourglass_empty)),
    findsOneWidget,
    reason: 'a mark beside the wait',
  );
}
