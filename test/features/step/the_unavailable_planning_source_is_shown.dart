import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the unavailable planning source is shown
Future<void> theUnavailablePlanningSourceIsShown(WidgetTester tester) async {
  expect(find.text('The planner supplying this planning item is no longer available.'), findsOneWidget);
  expect(planningElement('detail'), findsNothing);
  expect(planningElement('crumb 0').hitTestable(), findsOneWidget);
}
