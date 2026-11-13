import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: no planning move warning is shown
Future<void> noPlanningMoveWarningIsShown(WidgetTester tester) async {
  // Keeping the question on screen after it was answered makes this fail.
  expect(planningElement('move-warning'), findsNothing);
}
