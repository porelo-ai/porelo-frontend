import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning owner link is absent
Future<void> thePlanningOwnerLinkIsAbsent(WidgetTester tester) async {
  expect(planningElement('detail'), findsOneWidget);
  expect(planningElement('owner-story'), findsNothing);
}
