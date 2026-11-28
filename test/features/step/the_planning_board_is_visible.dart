import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning board is visible
Future<void> thePlanningBoardIsVisible(WidgetTester tester) async {
  expect(planningElement('board-info'), findsOneWidget);
  expect(planningElement('crumb 0'), findsNothing);
}
