import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I go to the running work
Future<void> iGoToTheRunningWork(WidgetTester tester) async {
  await toThePlace(tester, 'work');
  await tester.tap(find.byKey(const Key('work-view-running')));
  await World.settle(tester);
}
