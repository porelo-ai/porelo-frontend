import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart' as host;
import 'package:porelo_frontend/src/app/host_progress.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/expandable_list_row.dart';
import 'package:porelo_frontend/src/ui/page_explanation.dart';

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
}
