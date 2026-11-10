import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: no planning move error is shown
Future<void> noPlanningMoveErrorIsShown(WidgetTester tester) async {
  // Adding a global red banner for a working-state drop, or keeping one after its batch is undone, makes this fail.
  expect(planningElement('move-error'), findsNothing);
}
