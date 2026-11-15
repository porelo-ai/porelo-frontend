import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../support/world.dart';

/// Usage: each start of {story} was reported once
Future<void> eachStartOfWasReportedOnce(WidgetTester tester, String story) async {
  await World.settle(tester);
  final offers = World.settings.plannedOffers.where((kept) => kept.story == story).toList();
  expect(offers, isNotEmpty, reason: 'a task of $story was started');
  for (final kept in offers) {
    // A report the planner took, sent again because the run could not start what its answer ordered, makes this fail.
    expect(World.planning.reported.where((report) => report == (kept.offer, PlanningTaskEvent.started)), hasLength(1));
    expect(kept.startedReported, isTrue, reason: 'the planner took the report');
  }
}
