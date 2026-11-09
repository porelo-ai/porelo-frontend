import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: no planning moves are pending
Future<void> noPlanningMovesArePending(WidgetTester tester) async {
  expect(planningElement('detail'), findsOneWidget);
  expect(planningElement('moves-pending'), findsNothing);
  expect(planningElement('save-moves'), findsNothing);
}
