import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../support/planning.dart';

/// Usage: I unfold closed planning states
Future<void> iUnfoldClosedPlanningStates(WidgetTester tester) async {
  await tester.ensureVisible(planningElement('fold-phase Done'));
  await tester.tap(planningElement('fold-phase Done'));
  await World.settle(tester);
}
