import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/project_details_page.dart';

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';

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
  await World.tapInView(tester, 'project-menu');
  await World.tapInView(tester, 'project.messages');
}

Future<void> _join(WidgetTester tester, String name) async {
  await tester.enterText(find.byKey(const Key('join-person')), name);
  await World.settle(tester);
  await World.tapInView(tester, 'join-it');
}

void main() {
  // Harm: a shortcut on a project opened on another machine must not review the current machine's project.
  testWidgets('a project on another machine blocks shortcuts and finder commands for the current selection', (
    tester,
  ) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [_project('!first:localhost')];
    await World.startApp(tester);
    World.elsewhere.theProjectsItHas = [_project('!second:localhost')];
    const second = Machine(name: 'elsewhere', socketPath: '/unused');
    await World.machines.add(second);
    await World.settle(tester);
    World.machines.select(World.machines.all.first);
    World.fleet.selectProject('checkout');
    World.shell.openProject(second, 'checkout');
    await World.settle(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await World.settle(tester);
    expect(World.backend.gateAskedIn, isEmpty, reason: 'the previous project must receive no review request');
    expect(World.shell.opened, isA<NothingOpened>());
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await World.settle(tester);
    await tester.enterText(find.byKey(const Key('command-query')), 'Review what is waiting');
    await World.settle(tester);
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, 'Review what is waiting at the gate')).enabled,
      isFalse,
    );
  });

  // Harm: a row's access tools must use its own forge and machine, independent of current selection.
  testWidgets('a row opens its own forge tools with no selected project', (tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [
      Project.from({'name': 'checkout', 'file': '/srv/checkout/project.yml'}),
    ];
    final organization = FixtureOrganization(organizationFor('mia'))
      ..projects = {
        'checkout': const ProjectView(name: 'checkout', revision: 'r1', address: 'git@forge.example.org:acme/api.git'),
      };
    await World.startApp(tester, organizationSource: organization);
    await World.forgeTokens.write('forge.example.org', World.forge.accepts);
    World.forge.repositoriesHere.add(
      const ForgeRepository(
        fullName: 'acme/api',
        sshUrl: 'git@forge.example.org:acme/api.git',
        httpsUrl: 'https://forge.example.org/acme/api.git',
        defaultBranch: 'main',
        admin: true,
        push: true,
        private: true,
      ),
    );
    await World.forges.add(name: 'Central', address: 'forge.example.org');
    World.fleet.selectProject(null);
    World.shell.goTo(Section.projects);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('projects-of-machines')));
    await World.settle(tester);
    await World.tapInView(tester, 'projects-menu ${World.machines.current.name}/checkout');
    expect(tester.widget<PopupMenuItem<String>>(find.byKey(const Key('project.forge'))).enabled, isTrue);
    await World.tapInView(tester, 'project.forge');
    expect(find.byKey(const Key('project-forge-dialog')), findsOneWidget);
    expect(World.fleet.selectedProject?.name, 'checkout');
  });

  // Harm: grouping equal names can send what is done to a project to the wrong machine.
  testWidgets('equal project names keep their own machine in the list and when opened', (tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [_project('!first:localhost')];
    await World.startApp(tester);
    World.elsewhere.theProjectsItHas = [_project('!second:localhost')];
    const second = Machine(name: 'elsewhere', socketPath: '/unused');
    await World.machines.add(second);
    World.shell.goTo(Section.projects);
    await World.settle(tester);
    final first = World.machines.all.first;
    expect(find.byKey(ValueKey('project ${first.name}/checkout')), findsOneWidget);
    expect(find.byKey(const ValueKey('project elsewhere/checkout')), findsOneWidget);
    await World.tapInView(tester, 'project elsewhere/checkout');
    expect(World.shell.itemMachine, second);
    expect(World.shell.itemProject, 'checkout');
    expect(World.machines.current, second, reason: 'what the page then does goes to its own machine');
    expect(find.byType(ProjectDetailsPage), findsOneWidget);
  });

  // Harm: a matching project name must not admit a person to another machine's room or account.
  testWidgets('the project menu joins the account on the selected machine', (tester) async {
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
      await _join(tester, 'Robin');
      expect(other.joins, previous, reason: 'another machine must not receive this join');
      expect(backend.joins, [(project: 'checkout', person: 'robin', reset: false)]);
      expect(backend.membersOf['checkout']!.single.person, 'robin');
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
    await _join(tester, 'robin');
    expect(World.backend.membersOf['checkout']!.single.person, 'robin');
    await World.tapInView(tester, 'open-element');
    expect(opened, [
      ['xdg-open', 'https://app.element.io/'],
    ]);
    await World.tapInView(tester, 'messages-close');
  });
}
