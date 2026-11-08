import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/start_work.dart';
import 'package:porelo_frontend/src/ui/start_work_view.dart';

import '../features/support/world.dart';

final _minutes = find.byKey(const Key('start-minutes'));
final _go = find.byKey(const Key('start-go'));

Future<({StartWork starting, FakeBackend machine})> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final machine = FakeBackend(const <Task>[]);
  final starting = StartWork();
  addTearDown(starting.dispose);
  await starting.open(machine, machine.theProjectsItHas.first);
  starting.chooseAgent('other-agent');
  starting.ask('Check the change');
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StartWorkDialog(starting: starting, onStart: () {}, onKeep: () {}),
      ),
    ),
  );
  await World.settle(tester);
  return (starting: starting, machine: machine);
}

void main() {
  // Harm: a session can acquire a hidden limit, or unattended work cannot choose its limit.
  testWidgets('only unattended work offers minutes and starts with thirty', (tester) async {
    final form = await _open(tester);
    expect(_minutes, findsNothing);
    form.starting.chooseMode(Mode.unattended);
    await World.settle(tester);
    expect(tester.widget<TextField>(_minutes).controller!.text, '30');
    for (final mode in <Mode>[Mode.agent, Mode.shell]) {
      form.starting.chooseMode(mode);
      await World.settle(tester);
      expect(_minutes, findsNothing);
    }
  });

  // Harm: unattended work runs longer or shorter than the limit the person chose.
  testWidgets('the default and edited minutes reach the backend start', (tester) async {
    final form = await _open(tester);
    form.starting.chooseMode(Mode.unattended);
    await World.settle(tester);
    expect(tester.widget<FilledButton>(_go).onPressed, isNotNull);
    form.starting.begin(form.machine);
    expect(form.machine.startedMinutes, <int?>[30]);
    await tester.ensureVisible(_minutes);
    await tester.enterText(_minutes, '7');
    await World.settle(tester);
    form.starting.begin(form.machine);
    expect(form.machine.startedMinutes, <int?>[30, 7]);
  });

  // Harm: switching from an unattended run kills a session at a leftover time limit.
  testWidgets('agent and shell sessions send no minutes after an unattended choice', (tester) async {
    final form = await _open(tester);
    form.starting.chooseMode(Mode.unattended);
    await World.settle(tester);
    await tester.ensureVisible(_minutes);
    await tester.enterText(_minutes, '7');
    for (final mode in <Mode>[Mode.agent, Mode.shell]) {
      form.starting.chooseMode(mode);
      await World.settle(tester);
      expect(tester.widget<FilledButton>(_go).onPressed, isNotNull);
      form.starting.begin(form.machine);
    }
    expect(form.machine.startedMinutes, <int?>[null, null]);
  });

  // Harm: invalid input starts a run with a fallback limit or submits a refused start.
  for (final value in <String>['', '0', '-1', 'text', '1.5']) {
    testWidgets('invalid minutes "$value" disable Start with a reason', (tester) async {
      final form = await _open(tester);
      form.starting.chooseMode(Mode.unattended);
      await World.settle(tester);
      expect(tester.widget<FilledButton>(_go).onPressed, isNotNull);
      await tester.ensureVisible(_minutes);
      await tester.enterText(_minutes, value);
      await World.settle(tester);
      expect(tester.widget<FilledButton>(_go).onPressed, isNull);
      expect(tester.widget<TextField>(_minutes).decoration!.errorText, isNotEmpty);
      form.starting.begin(form.machine);
      expect(form.machine.startedMinutes, isEmpty);
      await tester.enterText(_minutes, '1');
      await World.settle(tester);
      expect(tester.widget<FilledButton>(_go).onPressed, isNotNull);
      form.starting.begin(form.machine);
      expect(form.machine.startedMinutes, <int?>[1]);
    });
  }
}
