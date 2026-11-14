import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning story {id} is in {state}
Future<void> thePlanningStoryIsIn(WidgetTester tester, String id, String state) async {
  final card = find.descendant(
    of: find.byKey(Key('planning-state $state')),
    matching: find.byKey(Key('planning-card $id')),
  );
  await revealPlanning(tester, card);
  expect(card, findsOneWidget);
}
