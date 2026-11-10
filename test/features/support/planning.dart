import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/planning_fake.dart';

import 'world.dart';

/// An independently mutable snapshot, with the exact design story set.
Map<String, dynamic> planningFixture() => mockPlanningBoard();

/// Pushes one complete answer for the scenario's known project.
Future<void> pushPlanning(WidgetTester tester, Map<String, dynamic> snapshot) async {
  World.planning.push('checkout', snapshot);
  await World.settle(tester);
}

/// The list of maps held by a snapshot.
List<Map<String, dynamic>> planningMaps(Map<String, dynamic> board, String field) =>
    (board[field] as List<dynamic>).cast<Map<String, dynamic>>();

/// A named planning element, required to exist before reading it.
Finder planningElement(String key) => find.byKey(Key('planning-$key'));

/// The plain text below one known planning element.
String planningText(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  return tester
      .widgetList<Text>(find.descendant(of: finder, matching: find.byType(Text), matchRoot: true))
      .map((text) => text.data ?? '')
      .join(' ');
}

/// The pointer held over a planning drop target until a scenario releases it.
TestGesture? planningDrag;
