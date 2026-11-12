import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/forwarding.dart';
import '../support/rehearsal.dart';

/// Usage: a task in the forwarding repository has work waiting at its gate
Future<void> aTaskInTheForwardingRepositoryHasWorkWaitingAtItsGate(WidgetTester tester) => pictured(tester, () async {
  // The default branch as it stood before anything was forwarded: the forward must leave it there.
  Forwarding.defaultBefore = await theDefaultAtGitHub();
  Forwarding.branchesBefore = await theBranchesAtGitHub();
  final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
  await startWorkOn(
    tester,
    Forwarding.repository,
    name: 'forward-$stamp',
    prompt:
        'Add the file forward-$stamp.txt with the single line "forward $stamp", commit it on your branch '
        'and push it as your Porelo guide says. Change nothing else.',
  );
  // It works by itself; this waits, as the machine says it, for it to push to its gate.
  await pumpUntil(
    tester,
    () async {
      for (final task in await theTasksStartedSince()) {
        if ((task['waiting'] as int? ?? 0) > 0) {
          Rehearsal.waitingTask = task['name'] as String;
          // The driver's clean-up stops and removes it, and takes its branches at the forge away.
          final into = Platform.environment['PORELO_WALK_TASKS'] ?? '';
          if (into.isNotEmpty) {
            File(into).writeAsStringSync(
              '${task['container'] ?? task['name']} ${task['task'] ?? ''}\n',
              mode: FileMode.append,
              flush: true,
            );
          }
          return true;
        }
      }
      return false;
    },
    timeout: const Duration(minutes: 30),
    what: 'the task started on ${Forwarding.repository} to push to its gate',
  );
});
