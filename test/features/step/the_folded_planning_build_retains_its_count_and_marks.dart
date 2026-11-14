import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/planning_details.dart';

/// Usage: the folded planning build retains its count and marks
Future<void> theFoldedPlanningBuildRetainsItsCountAndMarks(WidgetTester tester) async {
  final phase = planningElement('phase Build');
  expect(phase, findsOneWidget);
  final tiles = find.descendant(
    of: phase,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('planning-card '),
    ),
  );
  // A folded phase builds only the tiles in its view: each tile's marks are counted once as the phase is walked.
  final marks = <String, (int, int)>{};
  var counted = false;
  await walkPlanning(tester, only: planningPhaseScroll(tester, 'Build'), () {
    if (!counted) {
      expect(find.descendant(of: phase, matching: find.text('10')), findsOneWidget);
      counted = true;
    }
    expect(find.descendant(of: phase, matching: find.byType(Card)), findsNothing);
    var (up, down) = (0, 0);
    for (final tile in tiles.evaluate().toList()) {
      final within = find.byWidget(tile.widget);
      final mark = (
        find.descendant(of: within, matching: find.text('▲▲')).evaluate().length,
        find.descendant(of: within, matching: find.text('▼')).evaluate().length,
      );
      marks[(tile.widget.key! as ValueKey<String>).value] = mark;
      up += mark.$1;
      down += mark.$2;
    }
    // No mark stands in the phase outside a story's tile.
    expect(find.descendant(of: phase, matching: find.text('▲▲')).evaluate().length, up);
    expect(find.descendant(of: phase, matching: find.text('▼')).evaluate().length, down);
    return false;
  });
  expect(marks, hasLength(10));
  expect(marks.values.fold<int>(0, (sum, mark) => sum + mark.$1), 7);
  expect(marks.values.fold<int>(0, (sum, mark) => sum + mark.$2), 3);
}
