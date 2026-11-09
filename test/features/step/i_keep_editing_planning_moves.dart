import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: I keep editing planning moves
Future<void> iKeepEditingPlanningMoves(WidgetTester tester) async {
  await tester.tap(planningElement('stay'));
  await World.settle(tester);
}
