import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: planning issue changes are saved
Future<void> planningIssueChangesAreSaved(WidgetTester tester) async {
  expect(planningText(tester, planningElement('move-notice')), 'Issue changes saved.');
  // The issue rows stand on a story's page, which builds all of them at once; the board waits out of sight under it.
  expect(planningElement('detail'), findsOneWidget);
  // Keeping a row's saving line after the planner confirmed it makes this fail.
  expect(find.textContaining('Saving…'), findsNothing);
}
