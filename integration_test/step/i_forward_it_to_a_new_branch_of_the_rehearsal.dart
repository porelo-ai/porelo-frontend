import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';

/// Usage: I forward it to a new branch of the rehearsal
Future<void> iForwardItToANewBranchOfTheRehearsal(WidgetTester tester) => pictured(tester, () async {
  // A branch of its own, never the default one: the rehearsal leaves the project's branches as they were.
  final branch = 'rehearsal-${DateTime.now().toUtc().millisecondsSinceEpoch}';
  Rehearsal.forwardedBranch = branch;
  final forward = find.ancestor(of: find.textContaining('Forward it'), matching: find.byType(FilledButton));
  await pumpUntil(tester, () => forward.evaluate().isNotEmpty, what: 'the gate to offer forwarding');
  await tester.ensureVisible(forward.first);
  await tester.tap(forward.first);
  await pumpFor(tester);
  final offered = find.byKey(const Key('forward-branch'));
  if (offered.evaluate().isNotEmpty) {
    await tester.tap(offered.first);
    await pumpFor(tester);
    await tester.tap(find.text('A new branch…').last);
    await pumpFor(tester);
  }
  await tester.enterText(find.byKey(const Key('forward-new-branch')), branch);
  await pumpFor(tester);
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
