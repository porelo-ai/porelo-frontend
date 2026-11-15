import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the start of the held report is not kept as reported
Future<void> theStartOfTheHeldReportIsNotKeptAsReported(WidgetTester tester) async {
  await World.settle(tester);
  final offer = World.planning.heldOffer;
  final kept = World.settings.plannedOffers.where((kept) => kept.offer == offer).toList();
  expect(kept, hasLength(1), reason: 'the window keeps the offer of the task it started');
  // A press of another task while the report waited, taken for the planner's answer, makes this fail.
  expect(kept.single.startedReported, isFalse);
}
