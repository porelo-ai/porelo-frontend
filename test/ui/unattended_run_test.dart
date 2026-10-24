import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/operations.dart';
import 'package:porelo_frontend/src/ui/start_work_view.dart';

import '../features/step/i_start_work_in_this_project.dart';
import '../features/support/world.dart';

Task _task({String activity = 'WORKING', int? inbox = 0, String prompt = 'Check the change'}) => Task.from({
  'name': 'porelo-checkout-check',
  'task': 'check',
  'project': 'checkout',
  'agent': 'other-agent',
  'mode': 'UNATTENDED',
  'prompt': prompt,
  'running': true,
  'helpers': 2,
  'activity': activity,
  'inboxWaiting': ?inbox,
});

Future<void> _start(WidgetTester tester) async {
  await World.startBackend([]);
  await World.startApp(tester);
  World.machines.fleet.selectProject('checkout');
  await iStartWorkInThisProject(tester);
  World.starting
    ..chooseAgent('other-agent')
    ..chooseMode(Mode.unattended);
  await tester.enterText(find.byKey(const Key('start-name')), 'check');
  await tester.enterText(find.byKey(const Key('start-prompt')), 'Check the change');
  await World.settle(tester);
  await tester.tap(find.byKey(const Key('start-go')));
  await World.settle(tester);
  expect(World.backend.starts, hasLength(1), reason: 'the fixture must actually launch work');
}

void main() {
  // Harm: leaving the start output interrupts work by canceling its start or stopping its task.
  testWidgets('leaving a completed unattended start keeps its work running', (tester) async {
    await _start(tester);
    var canceled = 0;
    World.backend.launch.onCancel = () => canceled++;
    expect(find.byKey(const Key('leave-run')), findsNothing, reason: 'Leave belongs after the start');
    World.backend.publish([_task()]);
    await World.backend.launch.close();
    await World.settle(tester);
    final canceledAtEnd = canceled;

    expect(find.byKey(const Key('leave-run')), findsOneWidget, reason: 'the completed start needs a way out');
    await tester.tap(find.byKey(const Key('leave-run')));
    await World.settle(tester);

    expect(find.byType(OperationOutputView), findsNothing, reason: 'Leave must close the view');
    expect(World.shell.opened, isA<NothingOpened>());
    expect(canceled, canceledAtEnd, reason: 'Leave must not cancel the start subscription');
    expect(World.operations.latest!.failed, isFalse, reason: 'the completed start must remain successful');
    expect(World.backend.starts, hasLength(1), reason: 'Leave must not launch another run');
    expect(World.backend.stops, isEmpty, reason: 'Leave must not stop any task');
    expect(World.backend.tasksNow.single.running, isTrue, reason: 'the work must carry on');
  });

  // Harm: restarting from a watched run launches work on the selected machine or project instead of its own.
  testWidgets('restart reviews the watched task on its own machine before launching', (tester) async {
    await _start(tester);
    final original = World.machines.current;
    World.backend.publish([_task(inbox: 2)]);
    await World.backend.launch.close();
    await World.settle(tester);
    expect(find.byKey(const Key('restart-run')), findsNothing, reason: 'a working task must not be restarted');
    World.backend.publish([_task(activity: 'ENDED')]);
    await World.settle(tester);
    expect(find.byKey(const Key('restart-run')), findsNothing, reason: 'no waiting messages means no restart offer');
    World.backend.publish([_task(activity: 'ENDED', inbox: null)]);
    await World.settle(tester);
    expect(find.byKey(const Key('restart-run')), findsNothing, reason: 'an older daemon reports no inbox count');
    World.backend.publish([_task(activity: 'ENDED', inbox: 2)]);
    await World.settle(tester);

    World.elsewhere = FakeBackend([_task(activity: 'ENDED', inbox: 9)])..nodeId = 'another-user';
    addTearDown(World.elsewhere.stop);
    await World.machines.add(Machine(name: 'elsewhere', socketPath: original.socketPath));
    World.machines.select(World.machines.all.last);
    World.machines.fleet.selectProject('billing');
    await World.settle(tester);
    expect(find.byKey(const Key('restart-run')), findsOneWidget, reason: 'the watched task has waiting messages');
    await tester.tap(find.byKey(const Key('restart-run')));
    await World.settle(tester);

    expect(find.byType(StartWorkDialog), findsOneWidget, reason: 'restart must wait for review in the start form');
    expect(World.machines.current, original, reason: 'the form must target the watched machine');
    expect(World.starting.project?.name, 'checkout', reason: 'the form must target the watched project');
    expect(tester.widget<TextField>(find.byKey(const Key('start-name'))).controller!.text, 'check');
    expect(tester.widget<TextField>(find.byKey(const Key('start-prompt'))).controller!.text, 'Check the change');
    expect(World.starting.agent, 'other-agent');
    expect(World.starting.mode, Mode.unattended);
    expect(World.backend.starts, hasLength(1), reason: 'opening the form must not launch work');
    expect(World.elsewhere.starts, isEmpty, reason: 'the selected machine must remain untouched');

    await tester.tap(find.byKey(const Key('start-go')));
    await World.settle(tester);
    expect(World.backend.starts, hasLength(2), reason: 'confirmation launches once on the original backend');
    final sent = World.backend.starts.last;
    expect(
      (sent.project, sent.task, sent.agent, sent.mode, sent.prompt),
      ('checkout', 'check', 'other-agent', Mode.unattended, 'Check the change'),
    );
    expect(World.elsewhere.starts, isEmpty);
    await World.backend.launch.close();
    await World.settle(tester);
  });
}
