import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I go to its work
Future<void> iGoToItsWork(WidgetTester tester) async {
  // From the project page's menu, where its work under Work is offered.
  await tester.tap(find.byKey(const Key('project-menu')));
  await World.settle(tester);
  await tester.tap(find.byKey(const ValueKey<String>('project.itsWork')).last);
  await World.settle(tester);
}
