import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: planning story {id} has a pending move
Future<void> planningStoryHasAPendingMove(WidgetTester tester, String id) async {
  // Removing the pending row or its individual Undo control makes these fail.
  expect(planningElement('pending $id'), findsOneWidget);
  expect(planningElement('undo $id'), findsOneWidget);
}
