import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: Reading is set and its reader runs with no dialog shown
Future<void> readingIsSetAndItsReaderRunsWithNoDialogShown(
  WidgetTester tester,
) => walked(tester, '8 [reader-unasked] read: Reading is set and its reader runs with no dialog shown', () async {
  // Nobody starts the readers: the window starts the planner's follow-up order by itself, and asks nothing on the way.
  Walk.tasksBefore = {...Walk.tasksBefore, ...Walk.builders};
  final readers = await theNewTasks(
    tester,
    'the reader tasks',
    Walk.issues.length,
    within: const Duration(minutes: 10),
  );
  Walk.readers = [for (final each in readers) theContainerOf(each)];
  final dialogs = find.byType(Dialog);
  if (dialogs.evaluate().isNotEmpty) fail('asked for the readers started with no dialog; the window shows one');
  for (final reader in readers) {
    final issue = await theIssueOf(theContainerOf(reader));
    if (issue == null) fail('asked ${theContainerOf(reader)} for the issue it reads; it works on none of the story');
    // A reader that ended already has been reported so: the planner moved its issue on to Review, often before the
    // last reader starts. Its end is read after the planner's state, which follows it.
    final state = await probeHolds(['issue-state', issue, 'Review']) && hasEnded(await theTask(theContainerOf(reader)))
        ? 'Review'
        : 'Reading';
    if (state == 'Review') noteStep('   $issue: its reader ended before this read; it stands in Review');
    await theIssueStandsIn(issue, Walk.issues.firstWhere((each) => each.id == issue).repository, state);
    // With the model the planner proposed, the walk's.
    final model = '${reader['model'] ?? ''}';
    if (!model.contains(Walk.model)) {
      fail('asked ${theContainerOf(reader)} for the model ${Walk.model}; it runs $model');
    }
  }
  noteStep('   the readers run in ${Walk.readers.join(', ')}');
  // Still held once the reading began: nothing took the landed work away.
  await theForgeHoldsTheLandedCommits();
});
