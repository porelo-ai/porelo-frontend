import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: I expand planning story issues {id}
Future<void> iExpandPlanningStoryIssues(WidgetTester tester, String id) async {
  await tester.ensureVisible(planningElement('issues $id'));
  await tester.tap(planningElement('issues $id'));
  await World.settle(tester);
}
