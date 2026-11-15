import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/planning_details.dart';

/// Usage: planning issues {ids} of {story} are in {state}
Future<void> planningIssuesOfAreIn(WidgetTester tester, String ids, String story, String state) async {
  // A story finished without its issues leaves them in their earlier state and fails here.
  for (final id in ids.split(' ')) {
    await revealPlanning(tester, planningElement('issue $story $id'));
    expect(planningText(tester, planningElement('issue $story $id')), contains(state));
  }
}
