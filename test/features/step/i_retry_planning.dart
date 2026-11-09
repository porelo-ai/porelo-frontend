import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: I retry planning
Future<void> iRetryPlanning(WidgetTester tester) async {
  expect(planningElement('retry'), findsOneWidget);
  await tester.tap(planningElement('retry'));
  await World.settle(tester);
  expect(planningElement('error'), findsNothing);
}
