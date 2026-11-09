import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../support/planning.dart';

/// Usage: i show closed planning states
Future<void> iShowClosedPlanningStates(WidgetTester tester) async {
  await tester.ensureVisible(planningElement('show-closed'));
  await tester.tap(planningElement('show-closed'));
  await World.settle(tester);
}
