import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I open the planning board
Future<void> iOpenThePlanningBoard(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('rail planning')));
  await World.settle(tester);
}
