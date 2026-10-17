import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the project {'checkout'} says {'2'} are waiting at the gate
Future<void> theProjectSaysAreWaitingAtTheGate(WidgetTester tester, String project, String count) async {
  await lookingAtTheProjects(tester, () async {
    // Waiting for review is what makes a project need a person, so it is a number on its card.
    expect(find.descendant(of: cardFor(project), matching: find.byType(Chip)), findsOneWidget);
    expect(find.descendant(of: cardFor(project), matching: find.text(count)), findsOneWidget);
  });
}
