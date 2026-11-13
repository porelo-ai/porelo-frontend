import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';
import '../support/planner_moves.dart';
import '../support/results_land.dart';

/// Usage: I choose Rework for the stopped reading
Future<void> iChooseReworkForTheStoppedReading(WidgetTester tester) =>
    walked(tester, '12 [findings] the person chooses Rework for the stopped reading', () async {
      for (final issue in await theStoppedIssues()) {
        await chooseRework(tester, issue.id);
        noteStep('   ${issue.id}: rework chosen');
      }
    });
