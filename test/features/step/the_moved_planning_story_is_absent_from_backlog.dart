import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the moved planning story is absent from backlog
Future<void> theMovedPlanningStoryIsAbsentFromBacklog(WidgetTester tester) async {
  expect(planningElement('card ST291'), findsOneWidget);
  expect(find.descendant(of: planningElement('state Backlog'), matching: planningElement('card ST291')), findsNothing);
}
