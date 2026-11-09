import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: planning issue changes are saved
Future<void> planningIssueChangesAreSaved(WidgetTester tester) async {
  expect(planningText(tester, planningElement('move-notice')), 'Issue changes saved.');
  expect(planningElement('moves-pending'), findsNothing);
}
