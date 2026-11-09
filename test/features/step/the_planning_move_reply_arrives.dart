import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning move reply arrives
Future<void> thePlanningMoveReplyArrives(WidgetTester tester) async {
  await completePlanningMove(tester);
}
