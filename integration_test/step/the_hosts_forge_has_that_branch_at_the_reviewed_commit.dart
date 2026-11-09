import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';
import '../support/remote.dart';

/// Usage: the host's forge has that branch at the reviewed commit
Future<void> theHostsForgeHasThatBranchAtTheReviewedCommit(WidgetTester tester) => pictured(tester, () async {
  final repository = (await theProjectsTasksOnTheHost()).firstWhere(
    (t) => t['name'] == Rehearsal.waitingTask,
  )['repository'];
  var said = '';
  await pumpUntil(
    tester,
    () async {
      said = await onTheTestMachine(
        'porelo build status -p "${Rehearsal.project}" -r "$repository" --branch="${Rehearsal.forwardedBranch}" 2>&1 || true',
      );
      return said.contains(Rehearsal.reviewedCommit!);
    },
    timeout: const Duration(minutes: 2),
    what: 'the forge to have ${Rehearsal.forwardedBranch} at the reviewed commit',
  );
});
