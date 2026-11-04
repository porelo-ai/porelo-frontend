import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I go to the list of work
Future<void> iGoToTheListOfWork(WidgetTester tester) async {
  await toThePlace(tester, 'work');
  await tester.tap(find.byKey(const Key('work-view-list')));
  await World.settle(tester);
}
