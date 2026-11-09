import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning move is refused with {name}
Future<void> thePlanningMoveIsRefusedWith(WidgetTester tester, String name) async {
  refusePlanningMove(name);
}
