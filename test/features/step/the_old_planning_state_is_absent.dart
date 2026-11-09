import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the old planning state is absent
Future<void> theOldPlanningStateIsAbsent(WidgetTester tester) async {
  expect(planningElement('state Investigating'), findsOneWidget);
  expect(planningElement('state In analysis'), findsNothing);
}
