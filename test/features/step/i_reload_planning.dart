import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: I reload planning
Future<void> iReloadPlanning(WidgetTester tester) async {
  expect(planningElement('reload'), findsOneWidget);
  await tester.ensureVisible(planningElement('reload'));
  await tester.tap(planningElement('reload'));
  await World.settle(tester);
  expect(planningElement('error'), findsNothing);
  expect(planningElement('watch-error'), findsNothing);
}
