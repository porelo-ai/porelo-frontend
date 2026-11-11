import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';
import '../support/remote.dart';

/// Usage: I forward it to the task's own branch on the host's forge
Future<void> iForwardItToTheTasksOwnBranchOnTheHostsForge(WidgetTester tester) => pictured(tester, () async {
  // The task's builds are the runs of its own forge branch, as the host names it; a forward elsewhere is the person's
  // push and builds nothing of the task's.
  final short = Rehearsal.waitingTask!.replaceFirst(RegExp('^porelo-${RegExp.escape(Rehearsal.project)}[-_]'), '');
  final named = await onTheTestMachine(
    'porelo task status "$short" 2>&1 | awk \'\$1 == "forge" { print \$2 }\' || true',
  );
  final branch = named.trim().isEmpty ? 'porelo/$short' : named.trim();
  Rehearsal.forwardedBranch = branch;
  final forward = find.ancestor(of: find.textContaining('Forward it'), matching: find.byType(FilledButton));
  await pumpUntil(tester, () => forward.evaluate().isNotEmpty, what: 'the gate to offer forwarding');
  await tester.ensureVisible(forward.first);
  await tester.tap(forward.first);
  await pumpFor(tester);
  // Chosen where the forge lists it already, named as a new branch where it does not yet.
  final offered = find.byKey(const Key('forward-branch'));
  if (offered.evaluate().isNotEmpty) {
    await tester.tap(offered.first);
    await pumpFor(tester);
    final listed = find.text(branch);
    await tester.tap(listed.evaluate().isNotEmpty ? listed.last : find.text('A new branch…').last);
    await pumpFor(tester);
  }
  final field = find.byKey(const Key('forward-new-branch'));
  if (field.evaluate().isNotEmpty) {
    await tester.enterText(field, branch);
    await pumpFor(tester);
  }
  await tester.tap(find.widgetWithText(FilledButton, 'Forward it'));
  await pumpFor(tester);
  // Sent once the host no longer holds the work at the gate; a refusal stays on screen and is the failure.
  await pumpUntil(
    tester,
    () async {
      final task = (await theProjectsTasksOnTheHost()).where((t) => t['name'] == Rehearsal.waitingTask).firstOrNull;
      return task != null && (task['waiting'] as int? ?? 0) == 0;
    },
    timeout: const Duration(minutes: 3),
    what: 'the gate to send it to ${Rehearsal.forwardedBranch}',
  );
});
