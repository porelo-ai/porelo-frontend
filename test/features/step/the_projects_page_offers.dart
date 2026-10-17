import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the project's page offers {'What this project may reach'}
///
/// As a point of its own on the project's page, not in a menu.
Future<void> theProjectsPageOffers(WidgetTester tester, String point) async {
  // The page's points are in its project's menu (walk 10).
  await tester.tap(find.byKey(const Key('project-menu')));
  await World.settle(tester);
  expect(find.text(point), findsOneWidget);
  await tester.tapAt(Offset.zero);
  await World.settle(tester);
}
