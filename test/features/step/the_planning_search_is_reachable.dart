import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning search is reachable
Future<void> thePlanningSearchIsReachable(WidgetTester tester) async {
  await tester.ensureVisible(planningElement('search'));
  expect(planningElement('search').hitTestable(), findsOneWidget);
  expect(tester.takeException(), isNull);
}
