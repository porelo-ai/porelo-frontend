import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/planning_details.dart';

/// Usage: I fold the planning phase {name}
Future<void> iFoldThePlanningPhase(WidgetTester tester, String name) async {
  await tapPlanning(tester, planningElement('fold-phase $name'));
}
