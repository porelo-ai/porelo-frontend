import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';
import '../support/planning.dart';
import '../support/world.dart';

/// Usage: I hold planning story {id} over {state}
Future<void> iHoldPlanningStoryOver(WidgetTester tester, String id, String state) async {
  final source = planningElement('card $id');
  // The state's heading is where a card is dropped; the state's whole group is a sliver without a box.
  final target = planningElement('drop $state');
  // Removing a card or target from the board makes these fail before the gesture.
  await revealPlanning(tester, target);
  await revealPlanning(tester, source);
  expect(source, findsOneWidget);
  expect(target, findsOneWidget);
  // Until a card is held over it, the heading names its state.
  expect(find.descendant(of: target, matching: find.text(state)), findsOneWidget);
  await Scrollable.ensureVisible(
    target.evaluate().single,
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
  // Once a move is staged, the pending list shortens the board, so the grip is the card's visible part.
  final visible = tester.getRect(source).intersect(tester.getRect(planningElement('board-scroll')));
  planningDrag = await tester.startGesture(visible.topLeft + const Offset(20, 20));
  await planningDrag!.moveBy(const Offset(0, -20));
  await tester.pump();
  final over = tester.getRect(target).intersect(tester.getRect(planningElement('board-scroll')));
  await planningDrag!.moveTo(over.center);
  await tester.pump();
}
