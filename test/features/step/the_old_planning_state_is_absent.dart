import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the old planning state is absent
Future<void> theOldPlanningStateIsAbsent(WidgetTester tester) async {
  // A state's group is built whether or not its phase shows it; only its cards wait for the view.
  expect(find.byKey(const Key('planning-state Investigating'), skipOffstage: false), findsOneWidget);
  expect(find.byKey(const Key('planning-state In analysis'), skipOffstage: false), findsNothing);
}
