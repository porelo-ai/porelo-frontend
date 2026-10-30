import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/projects_page.dart';
import 'package:porelo_frontend/src/ui/project_details_page.dart';
import 'package:porelo_frontend/src/ui/registry_persons.dart';
import 'package:porelo_frontend/src/app/registry_pages.dart';

import '../support/registry_page_source.dart';

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
  await World.tapInView(tester, 'project-menu');
  await World.tapInView(tester, 'project.messages');
}

Future<void> _join(WidgetTester tester, String name) async {
  await tester.enterText(find.byKey(const Key('join-person')), name);
  await World.settle(tester);
  await World.tapInView(tester, 'join-it');
}

void main() {
  // Harm: registry actions must reach the verified admission without changing another daemon's project.
  for (final scope in ['unwatched machine', 'unwatched project', 'unfollowed project']) {
    testWidgets('the finder reaches registry actions on an $scope', (tester) async {
      await World.startBackend(World.work);
      final watched = scope == 'unfollowed project';
      final project = scope == 'unwatched machine' ? null : 'admitted';
      final operation = project == null ? RegistryOperation.bringState : RegistryOperation.join;
      final machine = watched ? Machine.local() : const Machine(name: 'unwatched', socketPath: '/unwatched');
      final target = (registry: 'registry', host: machine.name, project: project);
      final source = FakeRegistryPageSource(
        RegistryPageSnapshot(
          items: [
            RegistryPageItem(
              target: target,
              machine: machine,
              role: 'developer',
              state: 'admitted',
              revision: 'r1',
              allowed: {operation},
            ),
          ],
        ),
      );
      final registry = RegistryPages(
        source: source,
        features: RegistryPageFeatures(operations: {operation}),
      );
      addTearDown(registry.dispose);
      await World.startApp(tester, registryPages: registry);
      World.fleet.selectProject('checkout');
      if (project == null) {
        World.shell.openMachine(machine, target: target);
      } else {
        World.shell.openProject(machine, project, target: target);
      }
      await World.settle(tester);
      final previousMachine = World.machines.current;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await World.settle(tester);
      final label = project == null ? 'Bring the state to the host' : 'Join';
      await tester.enterText(find.byKey(const Key('command-query')), label);
      await World.settle(tester);
      final command = find.widgetWithText(ListTile, label);
      expect(command, findsOneWidget, reason: 'the finder must offer the verified item operation');
      expect(tester.widget<ListTile>(command).enabled, isTrue, reason: 'registry actions need no local following');
      await tester.tap(command);
      await World.settle(tester);
      expect(source.published, isEmpty, reason: 'the finder reveals the operation before it is invoked');
      await World.tapInView(tester, 'highlighted');
      expect(source.published, [(target: target, operation: operation, person: null)]);
      expect(source.applications, [(target: target, revision: 'revision-2')]);
      expect(World.shell.itemRegistryTarget, target, reason: 'the finder must retain the verified admission');
      expect(World.machines.current, previousMachine);
      expect(World.fleet.selectedProject?.name, 'checkout');
    });
  }

  // Harm: a shortcut on an unwatched project must not review another machine's project.
  testWidgets('an unwatched project blocks shortcuts and finder commands for the old selection', (tester) async {
    await World.startBackend(World.work);
    const remote = Machine(name: 'unwatched', socketPath: '/unwatched');
    const target = (registry: 'registry', host: 'unwatched', project: 'checkout');
    final registry = RegistryPages(
      source: FakeRegistryPageSource(
        const RegistryPageSnapshot(
          items: [
            RegistryPageItem(target: target, machine: remote, role: 'developer', state: 'admitted', revision: 'r1'),
          ],
        ),
      ),
    );
    addTearDown(registry.dispose);
    await World.startApp(tester, registryPages: registry);
    World.fleet.selectProject('checkout');
    World.shell.goTo(Section.projects);
    await World.settle(tester);
    await World.tapInView(tester, 'project registry/unwatched/checkout');
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
  testWidgets('a followed row opens its own forge tools with no selected project', (tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [
      Project.from({
        'name': 'checkout',
        'file': '/srv/checkout/project.yml',
        'following': {'url': 'git@forge.example.org:acme/api.git'},
      }),
    ];
    await World.startApp(tester);
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
    await World.tapInView(tester, 'projects-menu ${World.machines.current.name}/checkout');
    expect(tester.widget<PopupMenuItem<String>>(find.byKey(const Key('project.forge'))).enabled, isTrue);
    await World.tapInView(tester, 'project.forge');
    expect(find.byKey(const Key('project-forge-dialog')), findsOneWidget);
    expect(World.fleet.selectedProject?.name, 'checkout');
  });

  // Harm: withdrawing one registry admission must not expose another registry's person actions.
  testWidgets('a withdrawn open admission does not fall back to a surviving registry', (tester) async {
    await World.startBackend(World.work);
    final machine = Machine.local();
    const person = RegistryPerson(login: 'bob', name: 'Bob');
    RegistryPageItem item(String registry) => RegistryPageItem(
      target: (registry: registry, host: machine.name, project: 'checkout'),
      machine: machine,
      role: 'project admin',
      state: 'registered',
      revision: 'revision-1',
      members: const [RegistryMember(person: person, role: 'developer', state: 'active')],
      allowed: {RegistryOperation.projectLock},
    );
    final source = FakeRegistryPageSource(
      RegistryPageSnapshot(items: [item('first'), item('second')], people: const [person]),
    );
    final registry = RegistryPages(
      source: source,
      features: const RegistryPageFeatures(operations: {RegistryOperation.projectLock}),
    );
    addTearDown(registry.dispose);
    await World.startApp(tester, registryPages: registry);
    World.shell.openProject(machine, 'checkout', target: item('first').target);
    await World.settle(tester);
    expect(find.byKey(const Key('person-menu bob')), findsOneWidget);
    source.snapshot = RegistryPageSnapshot(items: [item('second')], people: const [person]);
    await registry.refresh();
    await World.settle(tester);
    expect(find.byKey(const Key('person-menu bob')), findsNothing);
    expect(source.published, isEmpty);
  });

  // Harm: two registries must not share one access row or inherit each other's permissions.
  testWidgets('matching project and host names in separate registries remain separate rows', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    final machine = World.machines.current;
    const person = RegistryPerson(login: 'bob', name: 'Bob');
    final source = FakeRegistryPageSource(
      RegistryPageSnapshot(
        people: const [person],
        items: [
          for (final name in ['first-registry', 'second-registry'])
            RegistryPageItem(
              target: (registry: name, host: machine.name, project: 'checkout'),
              machine: machine,
              role: name == 'first-registry' ? 'developer' : 'project admin',
              state: 'registered',
              revision: 'revision-1',
              members: const [RegistryMember(person: person, role: 'developer', state: 'active')],
              allowed: name == 'second-registry' ? {RegistryOperation.projectLock} : {},
            ),
        ],
      ),
    );
    final registry = RegistryPages(
      source: source,
      features: const RegistryPageFeatures(operations: {RegistryOperation.projectLock}),
    );
    addTearDown(registry.dispose);
    await registry.refresh();
    RegistryPageItem? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => opened == null
                ? ProjectsPage(
                    machines: World.machines,
                    registry: registry,
                    muted: const {},
                    onProject: (_, _) {},
                    onAdmission: (item) => setState(() => opened = item),
                    menuFor: (_, _) => [],
                    onFromARepository: null,
                    onFollow: null,
                  )
                : ProjectDetailsPage(
                    machine: machine,
                    project: World.fleet.projects.singleWhere((project) => project.name == 'checkout'),
                    admission: opened,
                    registry: registry,
                    commands: registryItemCommands(context, registry, opened!, []),
                    onBack: () {},
                    onMachine: () {},
                  ),
          ),
        ),
      ),
    );
    await World.settle(tester);
    expect(find.text('checkout'), findsNWidgets(2));
    await tester.enterText(find.byKey(const Key('projects-filter')), 'second-registry');
    await World.settle(tester);
    await World.tapInView(tester, 'project second-registry/${machine.name}/checkout');
    await World.tapInView(tester, 'person-menu bob');
    await World.tapInView(tester, 'registry.projectLock');
    await World.tapInView(tester, 'registry-confirm');
    expect(source.published, [
      (
        target: (registry: 'second-registry', host: machine.name, project: 'checkout'),
        operation: RegistryOperation.projectLock,
        person: 'bob',
      ),
    ]);
    expect(source.hostPersons.keys, [(registry: 'second-registry', host: machine.name, project: 'checkout')]);
  });

  // Harm: grouping equal names can send access changes to the wrong machine.
  testWidgets('filtered projects retain their machine before a person action', (tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [_project('!first:localhost')];
    await World.startApp(tester);
    World.elsewhere.theProjectsItHas = [_project('!second:localhost')];
    const second = Machine(name: 'elsewhere', socketPath: '/unused');
    await World.machines.add(second);
    await World.settle(tester);
    final first = World.machines.current;
    const person = RegistryPerson(login: 'bob', name: 'Bob', email: 'bob@example.org');
    RegistryTarget target(Machine machine) => (registry: 'registry', host: machine.name, project: 'checkout');
    final source = FakeRegistryPageSource(
      RegistryPageSnapshot(
        people: const [person],
        items: [
          for (final machine in [first, second])
            RegistryPageItem(
              target: target(machine),
              machine: machine,
              role: 'project admin',
              roleOperations: const {RegistryOperation.projectLock},
              state: 'registered',
              revision: 'revision-1',
              allowed: machine == second ? {RegistryOperation.projectLock} : {},
              administrators: const [person],
              members: const [RegistryMember(person: person, role: 'developer', state: 'active')],
            ),
        ],
        applied: {
          for (final machine in [first, second])
            target(machine): const RegistryHostState(revision: 'revision-1', personStates: {'bob': 'active'}),
        },
      ),
    );
    final registry = RegistryPages(
      source: source,
      features: const RegistryPageFeatures(operations: {RegistryOperation.projectLock}),
    );
    addTearDown(registry.dispose);
    await registry.refresh();
    Machine? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AnimatedBuilder(
              animation: registry,
              builder: (context, _) => opened == null
                  ? ProjectsPage(
                      machines: World.machines,
                      registry: registry,
                      muted: const {},
                      onProject: (machine, project) => setState(() => opened = machine),
                      menuFor: (machine, project) => [],
                      onFromARepository: null,
                      onFollow: null,
                    )
                  : ProjectDetailsPage(
                      machine: opened!,
                      project: World.machines.of(opened!).projects.singleWhere((project) => project.name == 'checkout'),
                      registry: registry,
                      commands: const [],
                      onBack: () => setState(() => opened = null),
                      onMachine: () {},
                    ),
            ),
          ),
        ),
      ),
    );
    await World.settle(tester);
    expect(
      find.text('checkout'),
      findsNWidgets(2),
      reason: 'each machine needs its own row and permissions before an access action',
    );
    await World.tapInView(tester, 'project registry/${first.name}/checkout');
    await World.tapInView(tester, 'person-menu bob');
    final forbidden = tester.widget<PopupMenuItem<String>>(find.byKey(const Key('registry.projectLock')));
    expect(forbidden.enabled, isFalse);
    expect(find.textContaining('Only a project admin'), findsOneWidget);
    expect(source.published, isEmpty);
    await tester.tapAt(const Offset(5, 5));
    await World.settle(tester);
    await tester.tap(find.text('Projects').first);
    await World.settle(tester);
    await tester.enterText(find.byKey(const Key('projects-filter')), 'elsewhere');
    await World.settle(tester);
    expect(find.text('checkout'), findsOneWidget);
    expect(find.byKey(const Key('projects-menu registry/elsewhere/checkout')), findsOneWidget);
    await World.tapInView(tester, 'project registry/elsewhere/checkout');
    await World.tapInView(tester, 'person-menu bob');
    await World.tapInView(tester, 'registry.projectLock');
    expect(source.published, isEmpty, reason: 'the destructive action needs confirmation');
    source.failApply = true;
    await World.tapInView(tester, 'registry-confirm');
    expect(source.published, [(target: target(second), operation: RegistryOperation.projectLock, person: 'bob')]);
    expect(source.applications, [(target: target(second), revision: 'revision-2')]);
    expect(registry.applied(target(first))!.personStates, {'bob': 'active'});
    expect(registry.applied(target(second))!.personStates, {'bob': 'active'});
    expect(find.textContaining('change not confirmed on the host'), findsWidgets);
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
