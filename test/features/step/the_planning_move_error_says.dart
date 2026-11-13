import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning move error says {words}
Future<void> thePlanningMoveErrorSays(WidgetTester tester, String words) async {
  // Dropping the daemon reason from the board, or folding it away with its card, makes this fail.
  expect(planningText(tester, planningElement('move-error')), contains(words));
}
