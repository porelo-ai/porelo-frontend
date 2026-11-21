import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/gate_view.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';

/// Usage: I forward the work of each builder upstream at the gate
///
/// A guarded project's gate holds each builder's push until the person forwards it; only then does the forge hold
/// it and its readers see it.
Future<void> iForwardTheWorkOfEachBuilderUpstreamAtTheGate(WidgetTester tester) =>
    walked(tester, '7 the person forwards the work of each builder upstream at the gate', () async {
      for (final builder in Walk.builders) {
        await forwardTheWorkOf(tester, builder);
      }
    });

/// Forwards the push of the task in [builder] waiting at its gate onto the branch the dialog names, from its row
/// under Needs you, and waits until the gate holds nothing of it.
Future<void> forwardTheWorkOf(WidgetTester tester, String builder) async {
  final task = '${(await theTask(builder))['name'] ?? ''}';
  if (task.isEmpty) fail('asked porelo for the name of $builder; it names none');
  final row = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        RegExp('^attention-row gate .*/${RegExp.escape(task)}\$').hasMatch((w.key! as ValueKey<String>).value),
  );
  final review = find.descendant(of: row, matching: find.byKey(const Key('gate-review')));
  await toThePlace(tester, 'attention');
  await pumpUntil(
    tester,
    () => review.evaluate().isNotEmpty && tester.widget<ButtonStyleButton>(review.first).onPressed != null,
    timeout: const Duration(minutes: 2),
    what: 'the review of $task offered on its row under Needs you',
  );
  await tester.ensureVisible(review.first);
  await tester.tap(review.first);
  await pumpFor(tester);
  final push = find.descendant(of: find.byType(GateView), matching: find.textContaining(' · waiting '));
  await pumpUntil(tester, () => push.evaluate().isNotEmpty, what: 'the push of $task at the gate');
  await tester.tap(push.first);
  await pumpFor(tester);
  final forward = find.ancestor(of: find.textContaining('Forward it'), matching: find.byType(FilledButton));
  await pumpUntil(
    tester,
    () => forward.evaluate().isNotEmpty && tester.widget<ButtonStyleButton>(forward.first).onPressed != null,
    what: 'the gate to offer forwarding $task',
  );
  await tester.ensureVisible(forward.first);
  await tester.tap(forward.first);
  await pumpFor(tester);
  // The dialog names the task's own branch where the gate knows it; else the repository's branches are offered,
  // its default first. It opens only once each forge kept in the settings has answered or failed, which reads its
  // token first: longer than a plain wait where a forge is kept.
  final offered = find.byKey(const Key('forward-branch'));
  final typed = find.byKey(const Key('forward-new-branch'));
  await pumpUntil(
    tester,
    () => offered.evaluate().isNotEmpty || typed.evaluate().isNotEmpty,
    timeout: const Duration(minutes: 2),
    what: 'the dialog to name a branch for $task',
  );
  final send = find.widgetWithText(FilledButton, 'Forward it');
  if (tester.widget<ButtonStyleButton>(send).onPressed == null) {
    if (offered.evaluate().isEmpty) fail('the dialog names no branch for $task and offers none');
    await tester.tap(offered.first);
    await pumpFor(tester);
    final items = find.byWidgetPredicate((w) => w is DropdownMenuItem<String?>);
    final listed = [
      for (final each in items.evaluate())
        if ((each.widget as DropdownMenuItem<String?>).value case final String value) value,
    ];
    if (listed.isEmpty) fail('the dialog offers no branch of the repository of $task');
    await tester.tap(find.text(listed.first).last);
    await pumpFor(tester);
  }
  await tester.tap(send);
  await pumpFor(tester);
  await pumpUntil(
    tester,
    () async => ((await theTask(builder))['waiting'] as int? ?? 0) == 0,
    timeout: const Duration(minutes: 3),
    what: 'the gate to forward the push of $task',
  );
  noteStep('   $task forwarded upstream');
}
