import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning story {id} shows reading {rounds}
Future<void> thePlanningStoryShowsReading(WidgetTester tester, String id, String rounds) async {
  final reading = planningElement('reading $id');
  expect(reading, findsOneWidget);
  final expected = rounds.split(', ').map((round) => 'reading $round').toList();
  for (final text in expected) {
    expect(find.descendant(of: reading, matching: find.text(text)), findsOneWidget);
  }
}
