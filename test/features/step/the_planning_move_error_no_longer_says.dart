import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning move error no longer says {words}
Future<void> thePlanningMoveErrorNoLongerSays(WidgetTester tester, String words) async {
  // Keeping a previous move's refusal beside the new one makes this fail.
  expect(planningText(tester, planningElement('move-error')), isNot(contains(words)));
}
