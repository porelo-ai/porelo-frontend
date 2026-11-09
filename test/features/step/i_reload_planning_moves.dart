import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: I reload planning moves
Future<void> iReloadPlanningMoves(WidgetTester tester) async {
  await tester.tap(planningElement('reload'));
  await World.settle(tester);
}
