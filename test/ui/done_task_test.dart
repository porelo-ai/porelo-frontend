import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../features/support/world.dart';

/// A task as the machine lists it: its container up, and its activity as given.
Task _task(String name, String activity, {int waiting = 0}) => Task.from(<String, dynamic>{
  'name': name,
  'task': name.replaceFirst('porelo-checkout-', ''),
  'project': 'checkout',
  'securityClass': 'guarded',
  'state': activity == 'DONE' ? 'done' : 'Up 4 minutes',
  'running': true,
  'activity': activity,
  'helpers': 0,
  'mode': 'SHELL',
  'waiting': waiting,
  'agent': 'an-agent',
});

String _text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  // Harm: work its agent said is done reads as running, so the person waits on it or counts it as busy.
  test('a task that said done sits as done, and does not need a person for that alone', () {
    expect(Attention.demandOf(_task('porelo-checkout-done', 'DONE'), const <Prompt>[]), Demand.done);
    expect(
      Attention.demandOf(
        Task.from(const <String, dynamic>{'name': 'porelo-checkout-done', 'running': false, 'activity': 'DONE'}),
        const <Prompt>[],
      ),
      Demand.done,
      reason: 'stopped after it said done, it is still done',
    );
    expect(
      Attention.demandOf(_task('porelo-checkout-done', 'DONE', waiting: 1), const <Prompt>[]),
      Demand.gate,
      reason: 'its work at the gate still waits for review',
    );
  });

  // Harm: a done task is drawn and counted as running in Work.
  testWidgets('Work shows a done task as done, and its running count leaves it out', (tester) async {
    await World.startBackend(<Task>[_task('porelo-checkout-done', 'DONE'), _task('porelo-checkout-busy', 'WORKING')]);
    await World.startApp(tester);
    World.shell.goTo(Section.work);
    await World.settle(tester);

    expect(_text(tester, 'work-list-subtitle'), contains('· 1 running'));
    expect(find.byKey(const ValueKey<String>('tile-state done')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('tile-state working')), findsOneWidget);
  });

  // Harm: under Needs you a done task's row reads as work still running.
  testWidgets('under Needs you, a done task with work at the gate is said to be done', (tester) async {
    await World.startBackend(<Task>[_task('porelo-checkout-done', 'DONE', waiting: 1)]);
    await World.startApp(tester);
    World.shell.goTo(Section.attention);
    await World.settle(tester);

    final row = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('attention-row tile ') &&
          key.value.endsWith('/porelo-checkout-done');
    });
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.textContaining('said its work is done')), findsOneWidget);
  });
}
