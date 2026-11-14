import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart' as host;
import 'package:porelo_frontend/src/app/host_progress.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/app/templates.dart';
import 'package:porelo_frontend/src/ui/expandable_list_row.dart';
import 'package:porelo_frontend/src/ui/machine_view.dart' show TemplateRow;
import 'package:porelo_frontend/src/ui/page_explanation.dart';
import 'package:porelo_frontend/src/ui/project_details_page.dart';

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';

Future<void> _tap(WidgetTester tester, String key) => World.tapInView(tester, key);

/// The window with machine `build` from the organization's card, connected, read as [me].
Future<Machine> _withTheCard(
  WidgetTester tester, {
  String me = 'hana',
  FixtureConnections? connections,
  OrganizationHost organizationHost = buildHost,
}) async {
  final source = FixtureOrganization(organizationFor(me, host: organizationHost));
  await World.startApp(
    tester,
    organizationSource: source,
    hostConnections: connections ?? FixtureConnections(['build']),
  );
  final card = host.HostCardSsh(
    name: 'build',
    address: buildHost.address!,
    sshPort: buildHost.port!,
    hostKey: buildHost.hostKey!,
    login: me,
    publicKey: buildHost.hostKey!,
    webPort: buildHost.webPort,
  );
  final machine = Machine.fromHostCard(card, socketPath: '/unused');
  await World.machines.add(machine);
  await World.settle(tester);
  return machine;
}

/// Machine `build`, whose daemon lists `demo` carried for this person, while the host says it waits for the token.
Future<Machine> _waitingDemo(WidgetTester tester, {FixtureConnections? connections}) async {
  await World.startBackend(World.work);
  World.backend.theProjectsItHas = [
    ...World.backend.theProjectsItHas,
    Project.from(const {
      'name': 'demo',
      'carried': true,
      'repositories': [
        {'name': 'demo'},
      ],
    }),
  ];
  // What `org status` answers for a project put on the machine before its admin gave the token.
  return _withTheCard(
    tester,
    connections: (connections ?? FixtureConnections(['build']))
      ..hostProgress = HostProgress.read('{"projects":[{"project":"demo","state":"waiting-for-token"}]}'),
  );
}

void main() {
  // Harm: a repository with commits not yet at central reads as at central, and its work is trusted as kept there.
  testWidgets('a project opened from its machine says of each repository whether it is at central', (tester) async {
    final tasks = [
      ...World.work,
      Task.from(const {
        'name': 'porelo-demo-docs',
        'task': 'docs',
        'project': 'demo',
        'repository': 'demo-docs',
        'running': true,
        'state': 'Up 2 minutes',
      }),
    ];
    await World.startBackend(tasks);
    World.backend.theProjectsItHas = [
      ...World.backend.theProjectsItHas,
      Project.from(const {
        'name': 'demo',
        'carried': true,
        'repositories': [
          {'name': 'demo'},
          {'name': 'demo-docs'},
        ],
      }),
    ];
    final connections = FixtureConnections(['build'])
      ..hostProgress = HostProgress.read('''
{"projects":[{"project":"demo","state":"carried","repositories":[
{"repository":"demo","state":"taken","central":{"state":"ahead","commits":2}},
{"repository":"demo-docs","state":"taken","central":{"state":"up-to-date"}}
]}]}
''');
    final machine = await _withTheCard(tester, connections: connections);
    World.shell.choosePlace(ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.projects));
    await World.settle(tester);
    await _tap(tester, 'project build/demo');
    for (final (repository, words) in [
      ('demo', ['carried', '2 commits ahead of central', 'no task running']),
      ('demo-docs', ['carried', 'at central', '1 task running: docs']),
    ]) {
      final row = find.byKey(Key('repository-$repository'));
      expect(row, findsOneWidget, reason: repository);
      for (final each in words) {
        expect(
          find.descendant(of: row, matching: find.textContaining(each)),
          findsOneWidget,
          reason: '$repository $each',
        );
      }
    }
  });

  // Harm: a repository the machine says it does not carry reads as carried, and work is started there to be refused.
  testWidgets('a repository its machine says it does not carry is not shown as carried', (tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [
      ...World.backend.theProjectsItHas,
      Project.from(const {
        'name': 'demo',
        'carried': true,
        'repositories': [
          {'name': 'demo', 'own': true},
          {'name': 'demo-api', 'carriedHere': true, 'central': 'up-to-date'},
          {'name': 'demo-docs', 'carriedHere': false},
        ],
      }),
    ];
    final connections = FixtureConnections(['build'])
      ..hostProgress = HostProgress.read('''
{"projects":[{"project":"demo","state":"carried","repositories":[
{"repository":"demo-api","state":"taken","central":{"state":"up-to-date"}},
{"repository":"demo-docs","state":"taken","central":{"state":"up-to-date"}}
]}]}
''');
    final machine = await _withTheCard(tester, connections: connections);
    World.shell.choosePlace(ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.projects));
    await World.settle(tester);
    await _tap(tester, 'project build/demo');
    await World.showRepository(tester, 'demo-docs');
    final row = find.byKey(const Key('repository-demo-docs'));
    expect(find.descendant(of: row, matching: find.textContaining('not carried here')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.textContaining('at central')), findsNothing);
    expect(tester.widget<ListTile>(row).onTap, isNull, reason: 'a tap on it starts work there');
  });

  // Harm: a repository the host says is not carried there, which the daemon does not list, is started from its row.
  testWidgets('a repository the host says the machine does not carry yet is not started from its row', (tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [
      ...World.backend.theProjectsItHas,
      Project.from(const {
        'name': 'demo',
        'file': '/srv/demo/project.yml',
        'repositories': [
          {'name': 'demo', 'own': true},
          {'name': 'demo-api', 'carriedHere': true, 'central': 'up-to-date'},
        ],
      }),
    ];
    final connections = FixtureConnections(['build'])
      ..hostProgress = HostProgress.read('''
{"projects":[{"project":"demo","state":"carried","repositories":[
{"repository":"demo-api","state":"taken","central":{"state":"up-to-date"}},
{"repository":"demo-docs","state":"waiting"}
]}]}
''');
    final machine = await _withTheCard(tester, connections: connections);
    World.shell.choosePlace(ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.projects));
    await World.settle(tester);
    await _tap(tester, 'project build/demo');
    final row = find.byKey(const Key('repository-demo-docs'));
    expect(find.descendant(of: row, matching: find.textContaining('not carried')), findsOneWidget);
    expect(tester.widget<ListTile>(row).onTap, isNull, reason: 'a tap on it starts work there');
    expect(
      tester.widget<ListTile>(find.byKey(const Key('repository-demo-api'))).onTap,
      isNotNull,
      reason: 'one carried starts',
    );
  });

  // Harm: what a person cannot read of the machine reads as nothing carried and nothing running.
  testWidgets("a project on a machine one is no Machine Admin of says what is not read", (tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [
      ...World.backend.theProjectsItHas,
      Project.from(const {
        'name': 'demo',
        'carried': true,
        'repositories': [
          {'name': 'demo'},
        ],
      }),
    ];
    final machine = await _withTheCard(tester, me: 'mia');
    World.shell.choosePlace(ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.projects));
    await World.settle(tester);
    await _tap(tester, 'project build/demo');
    final row = find.byKey(const Key('repository-demo'));
    expect(find.descendant(of: row, matching: find.textContaining('carried: not read')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.textContaining('central: not read')), findsOneWidget);
  });

  Future<Machine> demoFromTheMachine(WidgetTester tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [
      ...World.backend.theProjectsItHas,
      Project.from(const {
        'name': 'demo',
        'carried': true,
        'repositories': [
          {'name': 'demo'},
        ],
      }),
    ];
    final machine = await _withTheCard(tester);
    World.shell.choosePlace(ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.projects));
    await World.settle(tester);
    await _tap(tester, 'project build/demo');
    return machine;
  }

  // Harm: a machine that stopped answering shows its last list of work as what runs now.
  testWidgets('a project on a machine that does not answer says its tasks are not read, and the state', (tester) async {
    await demoFromTheMachine(tester);
    World.backend.absent = const VarlinkDisconnected('gone');
    World.backend.lose();
    await World.settle(tester);
    await World.showRepository(tester, 'demo');
    final row = find.byKey(const Key('repository-demo'));
    expect(find.descendant(of: row, matching: find.textContaining('tasks: not read')), findsOneWidget);
    final head = find.byType(PageHead).first;
    expect(
      find.descendant(of: head, matching: find.byType(StateChip)),
      findsOneWidget,
      reason: "the machine's state",
    );
    expect(
      tester.widget<StateChip>(find.descendant(of: head, matching: find.byType(StateChip))).words,
      'Not connected',
    );
  });

  // Harm: a project shown from the finder keeps the machine it was last opened from, and that machine's states read as
  // the project's.
  testWidgets('a project shown by the finder forgets the machine it was last opened from', (tester) async {
    await demoFromTheMachine(tester);
    World.shell.show('work.start', section: Section.project);
    await World.settle(tester);
    final path = tester.widget<PageHead>(find.byType(PageHead).first).path.map((step) => step.label).toList();
    expect(path, ['My projects']);
    expect(find.byKey(const Key('project-general-page')), findsNothing);
  });

  // Harm: a project its machine waits for the token for reads as carried, on its row and on its page however that is
  // opened, and work is started there that the machine refuses.
  testWidgets('a project its machine waits for the token for is never carried, and no work starts in it', (
    tester,
  ) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [
      ...World.backend.theProjectsItHas,
      Project.from(const {
        'name': 'demo',
        'file': '/srv/demo/project.yml',
        'carried': true,
        'repositories': [
          {'name': 'demo', 'own': true},
          {'name': 'demo-api', 'carriedHere': true, 'central': 'up-to-date'},
        ],
      }),
    ];
    // What `org status` answers for a project put on the machine before its admin gave the token.
    final connections = FixtureConnections(['build'])
      ..hostProgress = HostProgress.read(
        '{"projects":[{"project":"demo","state":"waiting-for-token","why":"no key to read the central forge"}]}',
      );
    final machine = await _withTheCard(tester, connections: connections);
    World.shell.choosePlace(ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.projects));
    await World.settle(tester);
    final listRow = find.byKey(const ValueKey('projects-row build/demo'));
    expect(find.descendant(of: listRow, matching: find.textContaining('arried')), findsNothing);
    expect(find.descendant(of: listRow, matching: find.textContaining('waits for your')), findsOneWidget);

    Future<void> neverCarried(String route) async {
      final facts = tester.widget<Text>(find.byKey(const Key('project-facts'))).data!;
      expect(facts, isNot(contains('carried')), reason: route);
      expect(facts, contains('waits for your'), reason: route);
      await World.showRepository(tester, 'demo-api');
      final row = find.byKey(const Key('repository-demo-api'));
      expect(
        find.descendant(of: row, matching: find.textContaining('carried')),
        findsNothing,
        reason: route,
      );
      expect(tester.widget<ListTile>(row).onTap, isNull, reason: '$route: a tap on it starts work there');
      final commands = tester.widget<ProjectDetailsPage>(find.byType(ProjectDetailsPage)).commands;
      for (final id in ['work.start', 'project.startAgents']) {
        expect(commands.where((each) => each.id == id).single.available, isFalse, reason: '$route: $id');
      }
      expect(find.byKey(const Key('project-give-token')), findsOneWidget, reason: route);
    }

    await _tap(tester, 'project build/demo');
    await neverCarried('opened from its machine');
    World.shell.show('work.start', section: Section.project);
    await World.settle(tester);
    await neverCarried('opened by the finder');
  });

  // Harm: while the machine waits for the token for one new repository, the ones it has taken refuse work (seen live).
  testWidgets('a waiting project starts work in the repositories its machine has taken, not in the one that waits', (
    tester,
  ) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [
      ...World.backend.theProjectsItHas,
      Project.from(const {
        'name': 'demo',
        'file': '/srv/demo/project.yml',
        'carried': true,
        'repositories': [
          {'name': 'demo', 'own': true},
          {'name': 'demo-api', 'carriedHere': true, 'central': 'up-to-date'},
          {'name': 'demo-docs'},
        ],
      }),
    ];
    final connections = FixtureConnections(['build'])
      ..hostProgress = HostProgress.read(
        '{"projects":[{"project":"demo","state":"waiting-for-token","why":"demo-docs: waits for a central token",'
        '"repositories":[{"repository":"demo-api","state":"taken","central":{"state":"up-to-date"}},'
        '{"repository":"demo-docs","state":"waiting","why":"waits for a central token"}]}]}',
      );
    final machine = await _withTheCard(tester, connections: connections);
    World.shell.choosePlace(ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.projects));
    await World.settle(tester);
    await _tap(tester, 'project build/demo');
    await World.showRepository(tester, 'demo-api');
    final taken = find.byKey(const Key('repository-demo-api'));
    expect(find.descendant(of: taken, matching: find.textContaining('token')), findsNothing);
    expect(
      tester.widget<ListTile>(taken).onTap,
      isNotNull,
      reason: 'work starts in a repository the machine has taken',
    );
    final commands = tester.widget<ProjectDetailsPage>(find.byType(ProjectDetailsPage)).commands;
    expect(commands.where((each) => each.id == 'work.start').single.available, isTrue);
    await World.showRepository(tester, 'demo-docs');
    final waiting = find.byKey(const Key('repository-demo-docs'));
    expect(find.descendant(of: waiting, matching: find.textContaining('waits for your')), findsOneWidget);
    expect(tester.widget<ListTile>(waiting).onTap, isNull, reason: 'no work starts in the repository that waits');
    expect(find.byKey(const Key('project-give-token')), findsOneWidget);
    // The token is offered on the row that waits for it, not on the one taken.
    List<String> menu(String repository) => [
      for (final each in tester.widget<CommandMenu>(find.byKey(Key('repository-menu $repository'))).commands)
        each.label,
    ];
    expect(menu('demo-api').where((label) => label.contains('token')), isEmpty);
    expect(menu('demo-docs').where((label) => label.contains('token')), isNotEmpty);
  });

  // Harm: a project of a machine no organization's card names, opened from that machine's page while an organization is
  // read, crashes the window.
  testWidgets('a project of this machine opens from its page while an organization is read', (tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [
      ...World.backend.theProjectsItHas,
      Project.from(const {
        'name': 'demo',
        'file': '/srv/demo/project.yml',
        'repositories': [
          {'name': 'demo'},
        ],
      }),
    ];
    await World.startApp(
      tester,
      organizationSource: FixtureOrganization(organizationFor('hana')),
      hostConnections: FixtureConnections(['build']),
    );
    final machine = World.machines.current;
    expect(machine.hostCard, isNull);
    World.shell.choosePlace(ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.projects));
    await World.settle(tester);
    await _tap(tester, 'project ${machine.name}/demo');
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('repository-demo')), findsOneWidget);
  });

  // Harm: work starts in a project its machine waits for the token for, from *Start work* on the machine's page,
  // which takes the only project the machine lists.
  testWidgets('start work on a machine waiting for the token takes no project there', (tester) async {
    final machine = await _waitingDemo(tester);
    World.shell.choosePlace(ShellPlace(Section.machine, machine: machine));
    await World.settle(tester);
    // Asked of a machine listing other projects too, it is not offered among them.
    await World.tapInView(tester, 'organization.startWork/build');
    await World.settle(tester);
    expect(find.byKey(const ValueKey('new-work-in demo')), findsNothing);
    await tester.tapAt(Offset.zero);
    await World.settle(tester);
    // Asked of a machine listing it alone, it is not taken for the one project there.
    World.backend.theProjectsItHas = [
      for (final each in World.backend.theProjectsItHas)
        if (each.name == 'demo') each,
    ];
    await World.tapInView(tester, 'organization.startWork/build');
    await World.settle(tester);
    expect(World.backend.taken, isEmpty);
    expect(World.starting.project?.name, isNot('demo'));
  });

  // Harm: a saved job starts in a project its machine waits for the token for.
  testWidgets('a saved job does not start in a project its machine waits for the token for', (tester) async {
    final machine = await _waitingDemo(tester);
    await World.templates.keep(
      const Template(name: 'nightly', project: 'demo', agent: 'an-agent', mode: Mode.agent, prompt: 'run'),
    );
    World.shell.choosePlace(ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.projects));
    await World.settle(tester);
    await _tap(tester, 'project build/demo');
    // Below the page's explanation, which stands open the first time.
    final row = tester.widget<TemplateRow>(find.byType(TemplateRow, skipOffstage: false));
    expect(row.unavailable, isNotNull);
    row.onPressed();
    await World.settle(tester);
    expect(World.backend.taken, isEmpty);
    expect(World.starting.project, isNull);
  });

  // Harm: opening the start form asks the machine as root for a person who is no Machine Admin of it, a refused login
  // that counts against them.
  testWidgets('starting work as a member asks the machine nothing as root', (tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [
      ...World.backend.theProjectsItHas,
      Project.from(const {
        'name': 'demo',
        'file': '/srv/demo/project.yml',
        'repositories': [
          {'name': 'demo'},
        ],
      }),
    ];
    final connections = FixtureConnections(['build']);
    final machine = await _withTheCard(tester, me: 'mia', connections: connections);
    World.shell.choosePlace(ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.projects));
    await World.settle(tester);
    await _tap(tester, 'project build/demo');
    await World.showRepository(tester, 'demo');
    await tester.tap(find.byKey(const Key('repository-demo')));
    await World.settle(tester);
    expect(World.starting.project?.name, 'demo', reason: 'the start form opened');
    expect(connections.asked.where((each) => each.startsWith('progress') || each.startsWith('refresh')), isEmpty);
  });

  // Harm: each page that shows the machine asks it again as root, a fan of logins its host counts, where one answer
  // per connection is what there is to read.
  testWidgets('the machine is asked how far it has come once, whichever of its pages open', (tester) async {
    final connections = FixtureConnections(['build']);
    final machine = await _waitingDemo(tester, connections: connections);
    int asks() => connections.asked.where((each) => each == 'progress build').length;
    expect(asks(), 1, reason: 'asked once as the connection was read');
    for (var round = 0; round < 2; round++) {
      World.shell.choosePlace(ShellPlace(Section.machine, machine: machine));
      await World.settle(tester);
      World.shell.choosePlace(ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.projects));
      await World.settle(tester);
      await _tap(tester, 'project build/demo');
    }
    expect(asks(), 1);
  });

  // Harm: Refresh leaves a project's page saying it waits for the token after the machine took it, and its work
  // refused, where Refresh is the way to read the machine again.
  testWidgets("Refresh asks the machine again on a project's page", (tester) async {
    final connections = FixtureConnections(['build']);
    final machine = await _waitingDemo(tester, connections: connections);
    await World.settings.setRefreshSeconds(0);
    World.shell.choosePlace(ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.projects));
    await World.settle(tester);
    await _tap(tester, 'project build/demo');
    expect(tester.widget<Text>(find.byKey(const Key('project-facts'))).data, contains('waits for your'));
    connections.hostProgress = HostProgress.read(
      '{"projects":[{"project":"demo","state":"carried","repositories":[{"repository":"demo","state":"taken"}]}]}',
    );
    await World.tapInView(tester, 'refresh-all');
    await World.settle(tester);
    expect(tester.widget<Text>(find.byKey(const Key('project-facts'))).data, isNot(contains('waits for your')));
  });

  // Harm: each start form a Machine Admin opens logs in to the machine as root again, for what it said already.
  testWidgets('opening the start form takes what the machine said, asking nothing more', (tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [
      ...World.backend.theProjectsItHas,
      Project.from(const {
        'name': 'demo',
        'file': '/srv/demo/project.yml',
        'repositories': [
          {'name': 'demo'},
        ],
      }),
    ];
    final connections = FixtureConnections(['build'])
      ..hostProgress = HostProgress.read(
        '{"projects":[{"project":"demo","state":"carried","repositories":[{"repository":"demo","state":"taken"}]}]}',
      );
    final machine = await _withTheCard(tester, connections: connections);
    World.shell.choosePlace(ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.projects));
    await World.settle(tester);
    await _tap(tester, 'project build/demo');
    await World.showRepository(tester, 'demo');
    await tester.tap(find.byKey(const Key('repository-demo')));
    await World.settle(tester);
    expect(World.starting.project?.name, 'demo', reason: 'the start form opened');
    expect(connections.asked.where((each) => each == 'progress build'), hasLength(1));
  });
}
