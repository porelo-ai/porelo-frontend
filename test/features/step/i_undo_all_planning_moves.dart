import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: I undo all planning moves
Future<void> iUndoAllPlanningMoves(WidgetTester tester) async {
  await tester.ensureVisible(planningElement('undo-all'));
  await tester.tap(planningElement('undo-all'));
  await World.settle(tester);
}
