import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: I save the planning moves
Future<void> iSaveThePlanningMoves(WidgetTester tester) async {
  await savePlanningMoves(tester);
}
