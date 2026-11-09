import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: I remember the planning board position
Future<void> iRememberThePlanningBoardPosition(WidgetTester tester) async {
  await rememberPlanningBoard(tester);
}
