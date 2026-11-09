import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';
import '../support/planning.dart';

/// Usage: I undo the planning moves
Future<void> iUndoThePlanningMoves(WidgetTester tester) async {
  await tapPlanning(tester, planningElement('undo-moves'));
}
