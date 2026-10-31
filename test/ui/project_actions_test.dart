import 'package:porelo_frontend/src/app/roles.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_host/porelo_host.dart';

import '../support/host_admin.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';

import '../features/step/the_project_has_the_repositories.dart';
import '../features/support/world.dart';

Future<void> _project(WidgetTester tester) async {
  await World.startBackend(World.work);
  await World.startApp(tester);
  await theProjectHasTheRepositories(tester, 'checkout', 'checkout, payments-api, billing-api');
  World.fleet.selectProject('checkout');
  World.shell.goTo(Section.project);
  await World.settle(tester);
}

Future<void> _start(WidgetTester tester) async {
  World.starting.chooseAgent('an-agent');
  await World.settle(tester);
  await World.tapInView(tester, 'start-go');
}

void main() {
  setUp(() => roles = Roles.fromArguments(const ['--roles', 'host-admin,project-admin']));
  tearDown(() => roles = const Roles());
  // Harm: take-off must not dispatch an unrelated host-person dialog or lose its association.
  testWidgets('registered project take-off waits for registry removal', (tester) async {
    await _project(tester);
    await World.settings.rememberHostUp(
      'orchard',
      HostUpRecord(
        scalewayProject: 'provider',
        publicKey: personKey,
        hostName: 'orchard',
        preparedHost: PreparedHost.read(hostValues()),
      ),
    );
    await World.settings.rememberProjectHost('checkout', 'orchard');
    await World.settle(tester);
    final menu = tester.widget<CommandMenu>(find.byKey(const Key('project-menu')));
    final command = menu.commands.singleWhere((each) => each.id == 'project.takeOffServer');
    expect(command.available, isFalse, reason: 'registry removal has no adapter yet');
    expect(World.settings.projectHost('checkout'), 'orchard');
  });

  // Harm: a changed current machine must not redirect a repository action from the displayed page.
  testWidgets('repository commands reselect the displayed project in the full shell', (tester) async {
    await _project(tester);
    final first = World.machines.current;
    const second = Machine(name: 'elsewhere', socketPath: '/unused');
    World.elsewhere.theProjectsItHas = List.of(World.backend.theProjectsItHas);
    await World.machines.add(second);
    World.shell.goTo(Section.projects);
    await World.settle(tester);
    await World.tapInView(tester, 'project ${first.name}/checkout');
    World.machines.select(second);
    await World.settle(tester);
    await World.fromARepositorysMenu(tester, 'billing-api', 'start-in');
    expect(World.machines.current, first, reason: 'the repository operation must reselect its displayed machine');
    await _start(tester);
    expect(World.backend.starts.map((start) => start.repository), ['billing-api']);
    expect(World.elsewhere.starts, isEmpty);
  });

  // Harm: work starts in a different repository than the row that opened the form.
  testWidgets('a row start keeps its repository until Change chooses another', (tester) async {
    await _project(tester);
    await World.fromARepositorysMenu(tester, 'payments-api', 'start-in');
    expect(find.byKey(const Key('start-repository')), findsNothing);
    expect(find.byKey(const Key('start-repository-change')), findsOneWidget);
    expect(find.text('payments-api'), findsWidgets);
    await _start(tester);
    expect(World.backend.starts.single.repository, 'payments-api');

    World.shell.goTo(Section.project);
    await World.settle(tester);
    await World.fromARepositorysMenu(tester, 'payments-api', 'start-in');
    await World.tapInView(tester, 'start-repository-change');
    await World.choose(tester, 'start-repository', 'start-repository-billing-api');
    await _start(tester);
    expect(World.backend.starts.map((each) => each.repository), <String>['payments-api', 'billing-api']);
  });

  // Harm: the visible row action starts different work than its menu action.
  testWidgets('the row button and menu start work in the same repository', (tester) async {
    await _project(tester);
    await World.tapInView(tester, 'repository-billing-api');
    expect(find.byKey(const Key('start-repository-change')), findsOneWidget);
    await _start(tester);
    expect(World.backend.starts.single.repository, 'billing-api');

    World.shell.goTo(Section.project);
    await World.settle(tester);
    await World.fromARepositorysMenu(tester, 'billing-api', 'start-in');
    await _start(tester);
    expect(World.backend.starts.map((each) => each.repository), <String>['billing-api', 'billing-api']);
  });

  // Harm: a project-wide start silently inherits the last repository row's choice.
  testWidgets('the project start menu asks which repository to use', (tester) async {
    await _project(tester);
    await World.fromARepositorysMenu(tester, 'billing-api', 'start-in');
    await World.tapInView(tester, 'start-not-now');
    await World.tapInView(tester, 'project-menu');
    await World.tapInView(tester, 'work.start');
    expect(find.byKey(const Key('start-repository')), findsOneWidget);
    expect(find.byKey(const Key('start-repository-change')), findsNothing);
    await _start(tester);
    expect(World.backend.starts, isEmpty);
    await World.choose(tester, 'start-repository', 'start-repository-payments-api');
    await _start(tester);
    expect(World.backend.starts.single.repository, 'payments-api');
  });

  // Harm: a row action launches work while its menu action refuses it.
  testWidgets('an unavailable row start has the menu reason and cannot start', (tester) async {
    await _project(tester);
    World.backend.theProjectsItHas = <Project>[
      for (final project in World.backend.theProjectsItHas)
        if (project.name == 'checkout')
          Project(
            name: project.name,
            securityClass: project.securityClass,
            file: '',
            mirror: project.mirror,
            pending: project.pending,
            tasks: project.tasks,
            running: project.running,
            prepared: project.prepared,
            preparedState: project.preparedState,
            repositories: project.repositories,
            repositoryStates: project.repositoryStates,
          )
        else
          project,
    ];
    await World.fleet.refresh(quietly: true);
    await World.settle(tester);
    final row = find.byKey(const Key('repository-payments-api'));
    expect(tester.widget<ListTile>(row).onTap, isNull);
    await World.tapInView(tester, 'repository-payments-api');
    expect(find.byKey(const Key('start-go')), findsNothing);
    expect(World.backend.starts, isEmpty);
    await tester.tap(find.byKey(const Key('repository-menu payments-api')));
    await World.settle(tester);
    final item = tester.widget<PopupMenuItem<String>>(find.byKey(const Key('start-in-payments-api')));
    expect(item.enabled, isFalse);
    expect(find.textContaining('checkout is not a project this machine follows'), findsOneWidget);
  });

  // Harm: a tile dispatches an action other than the command shown on it.
  testWidgets('a project menu runs its own command', (tester) async {
    await _project(tester);
    expect(World.notifications.mutedFor('checkout'), isFalse);
    await World.tapInView(tester, 'project-menu');
    await World.tapInView(tester, 'notifications.mute');
    expect(World.notifications.mutedFor('checkout'), isTrue);
    expect(World.backend.starts, isEmpty);
  });

  // Harm: a tile runs an action when the command says it must not run.
  testWidgets('an unavailable menu action shows its reason and does not run', (tester) async {
    await _project(tester);
    final menu = tester.widget<CommandMenu>(find.byKey(const Key('project-menu')));
    final command = menu.commands.singleWhere((each) => each.id == 'project.default');
    expect(command.available, isFalse);
    await World.tapInView(tester, 'project-menu');
    expect(find.textContaining(command.unavailable!), findsOneWidget);
    await World.tapInView(tester, 'project.default');
    expect(find.byKey(const Key('default-dialog')), findsNothing);
    expect(World.backend.starts, isEmpty);
  });

  // Harm: a server put up from where its keys cannot be kept, refused only after the wizard was filled.

  // Harm: replacing tiles must not strand commands that open review or repository tools.
  testWidgets('the project menu preserves work review and repository tools once each', (tester) async {
    await _project(tester);
    final menu = tester.widget<CommandMenu>(find.byKey(const Key('project-menu')));
    final ids = menu.commands.map((command) => command.id).toList();
    expect(
      ids.toSet(),
      containsAll([
        'work.start',
        'project.startAgents',
        'gate.open',
        'project.messages',
        'egress.open',
        'project.prepare',
        'project.sync',
        'project.backups',
        'project.delete',
      ]),
    );
    expect(ids.length, ids.toSet().length, reason: 'each operation has one unambiguous menu destination');
    expect(ids, isNot(contains('project.developers')), reason: 'person actions belong to verified-card lists');
  });
}
