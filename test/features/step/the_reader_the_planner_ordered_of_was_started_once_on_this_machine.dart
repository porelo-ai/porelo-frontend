import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import 'the_planner_orders_a_reader_of_after_the_next_reported_start.dart';

/// Usage: the reader the planner ordered of {issue} was started once on this machine
Future<void> theReaderThePlannerOrderedOfWasStartedOnceOnThisMachine(WidgetTester tester, String issue) async {
  await World.settle(tester);
  // A follow-up started by both the screen's run and the window, or by neither, makes this fail.
  expect(World.backend.startsOrdered.where((offer) => offer == followUpOffer), hasLength(1));
  expect(World.planning.followUpOnStart, isNull, reason: 'the answer carrying the reader was given');
  expect(find.byKey(const Key('planning-action-error')), findsNothing, reason: 'no second start was refused');
  expect(World.backend.tasksNow.where((task) => task.name.contains('reader-${issue.toLowerCase()}')), hasLength(1));
}
