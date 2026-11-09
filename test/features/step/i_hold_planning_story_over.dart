import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: I hold planning story {id} over {state}
Future<void> iHoldPlanningStoryOver(WidgetTester tester, String id, String state) async {
  final source = planningElement('card $id');
  final target = planningElement('state $state');
  final heading = find.descendant(of: target, matching: find.text(state));
  // Removing a card or target from the board makes these fail before the gesture.
  expect(source, findsOneWidget);
  expect(target, findsOneWidget);
  await Scrollable.ensureVisible(
    heading.evaluate().single,
    alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
  );
  await Scrollable.ensureVisible(
    source.evaluate().single,
    alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
  );
  await World.settle(tester);
  addTearDown(() async {
    final held = planningDrag;
    planningDrag = null;
    await held?.cancel();
  });
  planningDrag = await tester.startGesture(tester.getTopLeft(source) + const Offset(20, 20));
  await planningDrag!.moveBy(const Offset(0, -20));
  await tester.pump();
  await planningDrag!.moveTo(tester.getCenter(heading));
  await tester.pump();
}
