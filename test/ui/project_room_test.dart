import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../features/support/world.dart';

Project _project(String room) => Project.from({
  'name': 'checkout',
  'file': '/srv/checkout/project.yml',
  'messages': {
    'transport': 'matrix',
    'conversation': room,
    'reaches': ['127.0.0.1:8008'],
    'ready': true,
  },
});

Future<void> _openRoom(WidgetTester tester) async {
  World.fleet.selectProject('checkout');
  World.shell.goTo(Section.project);
  await World.settle(tester);
  await World.tapInView(tester, 'command-tile-project.messages');
}

Future<void> _join(WidgetTester tester, String name) async {
  await tester.enterText(find.byKey(const Key('join-person')), name);
  await World.settle(tester);
  await World.tapInView(tester, 'join-it');
}

void main() {
  // Harm: a matching project name must not admit a person to another machine's room or account.
  testWidgets('the project tile joins the typed account on the selected machine', (tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [_project('!first:localhost')];
    await World.startApp(tester);
    World.elsewhere.theProjectsItHas = [_project('!second:localhost')];
    const second = Machine(name: 'elsewhere', socketPath: '/unused');
    await World.machines.add(second);
    await World.settle(tester);
    final first = World.machines.current;
    for (final (machine, backend, other) in [
      (second, World.elsewhere, World.backend),
      (first, World.backend, World.elsewhere),
    ]) {
      World.machines.select(machine);
      await _openRoom(tester);
      final previous = other.joins.toList();
      await _join(tester, 'Michi');
      expect(other.joins, previous, reason: 'another machine must not receive this join');
      expect(backend.joins, [(project: 'checkout', person: 'michi', reset: false)]);
      expect(backend.membersOf['checkout']!.single.person, 'michi');
      await World.tapInView(tester, 'messages-close');
    }
  });

  // Harm: an account password in an opened URL leaks into browser history and the web service.
  testWidgets('Open Element opens only its public address after joining', (tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [_project('!first:localhost')];
    await World.startApp(tester);
    final previousDesk = desk;
    final opened = <List<String>>[];
    desk = Desk.of(
      'linux',
      const {},
      startDetached: (program, arguments) async {
        opened.add([program, ...arguments]);
      },
    );
    addTearDown(() => desk = previousDesk);
    await _openRoom(tester);
    expect(opened, isEmpty);
    await _join(tester, 'michi');
    expect(World.backend.membersOf['checkout']!.single.person, 'michi');
    await World.tapInView(tester, 'open-element');
    expect(opened, [
      ['xdg-open', 'https://app.element.io/'],
    ]);
    await World.tapInView(tester, 'messages-close');
  });
}
