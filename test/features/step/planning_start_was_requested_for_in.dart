import 'package:flutter_test/flutter_test.dart';

import 'package:porelo_frontend/src/ui/wizard.dart';

import '../support/planning.dart';

/// Usage: planning start was requested for {id} in {state}
Future<void> planningStartWasRequestedForIn(WidgetTester tester, String id, String state) async {
  expect(planningElement('start-request'), findsNothing);
  // Start work opens in the window's own wizard.
  expect(find.byType(Wizard), findsOneWidget);
  expect(find.textContaining(id), findsWidgets);
  expect(find.textContaining(state), findsWidgets);
}
