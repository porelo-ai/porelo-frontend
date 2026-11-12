import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: the story stands in Finished and porelo holds its records
Future<void> theStoryStandsInFinishedAndPoreloHoldsItsRecords(WidgetTester tester) =>
    walked(tester, '10 read: the story stands in Finished and porelo holds its records', () async {
      for (final issue in Walk.issues) {
        // The planner takes a finished issue's file out of the tree; the probe's store-issue reads only that file, so
        // the board and the story's file say where it stands.
        await probe(['issue-state', issue.id, 'Finished']);
        await inTheForge(['store-story', Walk.ownUrl, Walk.story!, issue.id, 'Finished']);
        noteStep('   ${issue.id}: its file is out of the tree in Finished, so store-issue was not asked');
      }
      await probe(['story-state', Walk.story!, 'Finished']);
      await probe(['records', Walk.since]);
    });
