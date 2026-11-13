import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: I leave planning anyway
Future<void> iLeavePlanningAnyway(WidgetTester tester) async {
  await tester.tap(planningElement('leave'));
  await World.settle(tester);
}
