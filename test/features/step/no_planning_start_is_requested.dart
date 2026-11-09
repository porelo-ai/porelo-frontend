import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: no planning start is requested
Future<void> noPlanningStartIsRequested(WidgetTester tester) async {
  // Requesting a start when a WORKING card returns to its own state makes this fail.
  expect(planningElement('start-request'), findsNothing);
}
