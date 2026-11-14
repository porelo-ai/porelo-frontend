import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/planning_details.dart';

/// Usage: the planning states put working states first
Future<void> thePlanningStatesPutWorkingStatesFirst(WidgetTester tester) async {
  const names = ['Implementing', 'Reworking', 'Review'];
  // A state's group is a sliver with no box of its own; its heading stands at the group's top.
  final phase = planningPhaseHolding(tester, find.byKey(const Key('planning-state Review'), skipOffstage: false));
  final view = tester.getRect(find.byWidget(phase.widget));
  final offsets = <String, double>{};
  await walkPlanning(tester, only: phase, () {
    for (final name in names) {
      final heading = planningElement('drop $name');
      if (!offsets.containsKey(name) && heading.evaluate().isNotEmpty) {
        // Where the heading stands in the whole column, whatever the column's scroll.
        offsets[name] = tester.getTopLeft(heading).dy - view.top + phase.position.pixels;
      }
    }
    return false;
  });
  expect(offsets.keys, unorderedEquals(names));
  for (final pair in [('Implementing', 'Review'), ('Reworking', 'Review')]) {
    expect(offsets[pair.$1], lessThan(offsets[pair.$2]!));
  }
}
