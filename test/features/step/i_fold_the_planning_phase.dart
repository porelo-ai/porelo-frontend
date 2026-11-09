import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: I fold the planning phase {name}
Future<void> iFoldThePlanningPhase(WidgetTester tester, String name) async {
  await tester.ensureVisible(planningElement('fold-phase $name'));
  await tester.tap(planningElement('fold-phase $name'));
  await World.settle(tester);
}
