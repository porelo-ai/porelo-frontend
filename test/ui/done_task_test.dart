import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/fleet_model.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/attention_view.dart';
import 'package:porelo_frontend/src/ui/machine_tree.dart';

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
  'repository': 'checkout',
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
    expect(
      find.byWidgetPredicate((widget) => widget is Tooltip && widget.message == '1 running'),
      findsOneWidget,
      reason: "the rail's count beside Work counts running work alone",
    );

    World.shell.choosePlace(
      ShellPlace(Section.machine, machine: World.machines.all.first, machineSection: MachineSection.managing),
    );
    await World.settle(tester);
    expect(find.text('1 task running'), findsOneWidget, reason: "the machine's Work card counts running work alone");
  });

  // Harm: a done task whose terminal was closed reads as one with no terminal open, which asks a person to open one.
  test('a done task says done even where its terminal ended', () {
    final fleet = FleetModel(FakeBackend(const <Task>[]));
    addTearDown(fleet.dispose);
    final tile = Tile(
      machine: const Machine(name: 'here', socketPath: '/unused'),
      fleet: fleet,
      demand: Demand.done,
      task: _task('porelo-checkout-done', 'DONE'),
    );
    expect(WorkRow.stateOf(tile, terminalEnded: true), 'done');
    expect(WorkRow.sentenceOf(tile, terminalEnded: true), startsWith('Done'));
  });

  // Harm: a project's or a repository's count of running work counts a task that said done, whose container is up.
  test("a project's and a repository's running counts leave out a done task", () {
    final done = _task('porelo-checkout-done', 'DONE');
    final busy = _task('porelo-checkout-busy', 'WORKING');
    final project = ProjectOnScreen(
      project: Project.from(const <String, dynamic>{'name': 'checkout', 'tasks': 2, 'running': 2}),
      tasks: <Task>[done, busy],
    );
    expect(project.running, 1);
    expect(
      countedIn(
        project: 'checkout',
        repository: Repository.from(const <String, dynamic>{'name': 'checkout', 'tasks': 2, 'running': 2}),
        tasks: <Task>[done, busy],
      ),
      '1 of 2 tasks running: busy',
    );
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
          key.value.startsWith('attention-row gate ') &&
          key.value.endsWith('/porelo-checkout-done');
    });
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.textContaining('said its work is done')), findsOneWidget);
  });
}
