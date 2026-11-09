import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I try to leave planning moves
Future<void> iTryToLeavePlanningMoves(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('rail work')));
  await World.settle(tester);
}
