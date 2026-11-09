import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the planning story {id} is in {state}
Future<void> thePlanningStoryIsIn(WidgetTester tester, String id, String state) async {
  expect(
    find.descendant(of: find.byKey(Key('planning-state $state')), matching: find.byKey(Key('planning-card $id'))),
    findsOneWidget,
  );
}
