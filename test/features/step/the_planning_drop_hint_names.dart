import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the planning drop hint names {state}
Future<void> thePlanningDropHintNames(WidgetTester tester, String state) async {
  // Removing the candidate hint from DragTarget makes this fail during a held drag.
  // The heading is built whether or not its phase shows it, so the hint is read even out of view.
  final heading = find.byKey(Key('planning-drop $state'), skipOffstage: false);
  expect(heading, findsOneWidget);
  expect(
    find.descendant(of: heading, matching: find.text('Drop here for $state', skipOffstage: false)),
    findsOneWidget,
  );
}
