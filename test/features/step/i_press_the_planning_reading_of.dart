import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: I press the planning reading of {id}
Future<void> iPressThePlanningReadingOf(WidgetTester tester, String id) async {
  final reading = planningElement('reading $id');
  await tester.ensureVisible(reading);
  await tester.tap(reading);
  await World.settle(tester);
  expect(find.byKey(const Key('needs-you-subtitle')), findsOneWidget);
}
