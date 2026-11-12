import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';
import '../support/planner_moves.dart';

/// Usage: the second stands in Reworking and Needs you lists it
Future<void> theSecondStandsInReworkingAndNeedsYouListsIt(WidgetTester tester) =>
    walked(tester, '10 [planner-moves] read: the second stands in Reworking and Needs you lists it', () async {
      // The second issue repository holds the seed's fault, which its reader blocks on.
      final second = Walk.issues.firstWhere((each) => each.repository == Walk.issueRepositories[1]);
      await pumpUntil(
        tester,
        () => probeHolds(['issue-state', second.id, 'Reworking']),
        timeout: const Duration(minutes: 5),
        what: 'the planner to set ${second.id} to Reworking',
      );
      await theIssueStandsIn(second.id, second.repository, 'Reworking');
      await toThePlace(tester, 'attention');
      await pumpUntil(
        tester,
        () => theEntryOf(second.id).evaluate().isNotEmpty,
        timeout: const Duration(minutes: 2),
        what: '${second.id} under what needs a person',
      );
    });
