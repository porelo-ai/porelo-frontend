import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: I confirm the planning move
Future<void> iConfirmThePlanningMove(WidgetTester tester) async {
  await tester.ensureVisible(planningElement('move-confirm'));
  await tester.tap(planningElement('move-confirm'));
  await World.settle(tester);
}
