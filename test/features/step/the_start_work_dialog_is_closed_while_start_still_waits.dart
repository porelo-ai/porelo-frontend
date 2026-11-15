import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/wizard.dart';

import '../support/world.dart';

/// Usage: the Start work dialog is closed while Start still waits
Future<void> theStartWorkDialogIsClosedWhileStartStillWaits(WidgetTester tester) async {
  await World.settle(tester);
  expect(find.byType(Wizard), findsNothing, reason: 'Start work closes once the planner took the order');
  expect(World.backend.startHeld?.isCompleted, isFalse, reason: 'the machine still holds the start');
}
