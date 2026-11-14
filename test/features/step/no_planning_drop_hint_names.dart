import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: no planning drop hint names {state}
Future<void> noPlanningDropHintNames(WidgetTester tester, String state) async {
  // Accepting a card over its current displayed state makes the hover hint appear and fails this check.
  // The heading is built whether or not its phase shows it, so the hint is read even out of view.
  final heading = find.byKey(Key('planning-drop $state'), skipOffstage: false);
  expect(heading, findsOneWidget);
  expect(find.descendant(of: heading, matching: find.text('Drop here for $state', skipOffstage: false)), findsNothing);
}
