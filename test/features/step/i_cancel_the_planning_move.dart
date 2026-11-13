import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: I cancel the planning move
Future<void> iCancelThePlanningMove(WidgetTester tester) async {
  await tester.ensureVisible(planningElement('move-cancel'));
  await tester.tap(planningElement('move-cancel'));
  await World.settle(tester);
}
