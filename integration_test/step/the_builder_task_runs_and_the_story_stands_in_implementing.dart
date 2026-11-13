import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';

/// Usage: the builder task runs and the story stands in Implementing
Future<void> theBuilderTaskRunsAndTheStoryStandsInImplementing(WidgetTester tester) =>
    walked(tester, '6 read: the builder task runs and the story stands in Implementing', () async {
      // A small task may have ended already by the time it is read.
      for (final builder in Walk.builders) {
        final task = await theTask(builder);
        expect(task['running'] == true || hasEnded(task), isTrue, reason: 'porelo says $builder ran: $task');
      }
      // The window posts STARTED after Start confirmed it, a while after porelo lists the task; the planner moves an
      // issue on only on that word. So nothing is judged before every issue left Backlog and every builder is bound
      // to its offer: an offer not yet bound is no task of the run, and a run of bound tasks all ended is not over.
      await pumpUntil(
        tester,
        () async =>
            await everyIssueIn(Walk.story!, const {'Implementing', 'Reading', 'Review'}) &&
            await everyTaskBound(Walk.story!, Walk.builders),
        timeout: Walk.bindDeadline,
        what: 'every issue to leave Backlog and every builder to be bound to its offer',
      );
      // Where every builder ended already, the window posted their ends too, and the run stands ended.
      Future<bool> allEndedNow() async {
        for (final builder in Walk.builders) {
          if (!hasEnded(await theTask(builder))) return false;
        }
        return true;
      }

      await pumpUntil(
        tester,
        () async =>
            await probeHolds(['work', Walk.story!, 'started']) ||
            (await probeHolds(['work', Walk.story!, 'ended']) && await allEndedNow()),
        timeout: const Duration(minutes: 2),
        what: 'the planner to have the run started, or ended once every builder ended',
      );
      if (await probeHolds(['work', Walk.story!, 'started'])) {
        await probe(['work', Walk.story!, 'started']);
      } else {
        noteStep('   every builder ended before this read; the run stands ended');
        await probe(['work', Walk.story!, 'ended']);
      }
      // A builder that ended already has been reported so: the planner moved its issue on to Reading. Its end is read
      // after the planner's state, which follows it.
      Future<bool> builderEnded(String repository) async {
        for (final builder in Walk.builders) {
          final task = await theTask(builder);
          if (task['repository'] == repository && hasEnded(task)) return true;
        }
        return false;
      }

      for (final issue in Walk.issues) {
        // A quick reader may even have read it already and moved it on to Review.
        final ended = await builderEnded(issue.repository);
        final state = !ended
            ? 'Implementing'
            : await probeHolds(['issue-state', issue.id, 'Review'])
            ? 'Review'
            : await probeHolds(['issue-state', issue.id, 'Reading'])
            ? 'Reading'
            : 'Implementing';
        if (state != 'Implementing') {
          noteStep('   ${issue.id}: its builder ended before this read; it stands in $state');
        }
        await theIssueStandsIn(issue.id, issue.repository, state);
      }
      var allEnded = true;
      for (final issue in Walk.issues) {
        if (!await builderEnded(issue.repository)) allEnded = false;
      }
      final story = !allEnded
          ? 'Implementing'
          : await probeHolds(['story-state', Walk.story!, 'Review'])
          ? 'Review'
          : await probeHolds(['story-state', Walk.story!, 'Reading'])
          ? 'Reading'
          : 'Implementing';
      await probe(['story-state', Walk.story!, story]);
    });
