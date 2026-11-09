import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning board position is retained
Future<void> thePlanningBoardPositionIsRetained(WidgetTester tester) async {
  expectPlanningBoardRetained(tester);
}
