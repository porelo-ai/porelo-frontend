import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: low priority planning stories are hidden
Future<void> lowPriorityPlanningStoriesAreHidden(WidgetTester tester) async {
  expect(planningElement('card ST127'), findsNothing);
  expect(planningElement('card ST193'), findsNothing);
  expect(planningElement('card ST5'), findsOneWidget);
}
