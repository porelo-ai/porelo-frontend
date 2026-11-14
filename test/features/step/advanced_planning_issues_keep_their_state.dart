import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/planning_details.dart';

/// Usage: advanced planning issues keep their state
Future<void> advancedPlanningIssuesKeepTheirState(WidgetTester tester) async {
  // Rendering every issue in the destination state makes the advanced issue assertions fail.
  for (final id in ['B540', 'B541']) {
    await revealPlanning(tester, planningElement('issue ST291 $id'));
    expect(planningText(tester, planningElement('issue ST291 $id')), contains('Implementing'));
  }
  // Ignoring the daemon issue states in the save reply leaves these in Backlog and fails.
  for (final id in [
    'B542',
    'B543',
    'B544',
    'B545',
    'B546',
    'B547',
    'B548',
    'B549',
    'B550',
    'B551',
    'B552',
    'HO156',
    'HO157',
  ]) {
    await revealPlanning(tester, planningElement('issue ST291 $id'));
    expect(planningText(tester, planningElement('issue ST291 $id')), contains('Review'));
  }
}
