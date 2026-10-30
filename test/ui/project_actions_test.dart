import 'package:porelo_frontend/src/app/roles.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_host/porelo_host.dart';

import '../support/host_admin.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';
import 'package:porelo_frontend/src/ui/machine_view.dart';

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
    await World.tapInView(tester, 'start-here-billing-api');
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
  testWidgets('the project start tile asks which repository to use', (tester) async {
    await _project(tester);
    await World.fromARepositorysMenu(tester, 'billing-api', 'start-in');
    await World.tapInView(tester, 'start-not-now');
    await World.tapInView(tester, 'start-work');
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
    final button = find.byKey(const Key('start-here-payments-api'));
    final tooltip = tester.widget<Tooltip>(find.ancestor(of: button, matching: find.byType(Tooltip)).first);
    expect(tooltip.message, 'checkout is not a project this machine follows');
    expect(tester.widget<TextButton>(button).onPressed, isNull);
    await World.tapInView(tester, 'start-here-payments-api');
    expect(find.byKey(const Key('start-go')), findsNothing);
    expect(World.backend.starts, isEmpty);
    await tester.tap(find.byKey(const Key('repository-menu payments-api')));
    await World.settle(tester);
    final item = tester.widget<PopupMenuItem<VoidCallback>>(find.byKey(const Key('start-in-payments-api')));
    expect(item.enabled, isFalse);
    expect(
      find.descendant(of: find.byKey(const Key('start-in-payments-api')), matching: find.byTooltip(tooltip.message!)),
      findsOneWidget,
    );
  });

  // Harm: a tile dispatches an action other than the command shown on it.
  testWidgets('a project tile runs its own command', (tester) async {
    await _project(tester);
    expect(World.notifications.mutedFor('checkout'), isFalse);
    await World.tapInView(tester, 'command-tile-notifications.mute');
    expect(World.notifications.mutedFor('checkout'), isTrue);
    expect(World.backend.starts, isEmpty);
  });

  // Harm: a tile runs an action when the command says it must not run.
  testWidgets('an unavailable tile shows its reason and does not run', (tester) async {
    await _project(tester);
    final menu = tester.widget<CommandMenu>(find.byKey(const Key('project-menu')));
    final command = menu.commands.singleWhere((each) => each.id == 'project.default');
    expect(command.available, isFalse);
    final tile = find.byKey(const Key('command-tile-project.default'));
    expect(find.descendant(of: tile, matching: find.byTooltip(command.unavailable!)), findsOneWidget);
    await World.tapInView(tester, 'command-tile-project.default');
    expect(find.byKey(const Key('default-dialog')), findsNothing);
    expect(World.backend.starts, isEmpty);
  });

  // Harm: a server put up from where its keys cannot be kept, refused only after the wizard was filled.

  testWidgets('every project menu command has exactly one tile and every tile a menu item', (tester) async {
    await _project(tester);
    final menu = tester.widget<CommandMenu>(find.byKey(const Key('project-menu')));
    final ids = menu.commands.map((each) => each.id).toSet();
    expect(ids, <String>{
      'work.start',
      'project.startAgents',
      'gate.open',
      'egress.open',
      'notifications.mute',
      'work.check',
      'project.prepare',
      'project.sync',
      'project.messages',
      'project.forge',
      'project.developers',
      'project.default',
      'project.backups',
      'project.clear',
      'project.server',
      'project.joinHost',
      'project.takeOffServer',
      'project.delete',
      'project.follow',
    });
    final tiles = find.byWidgetPredicate(
      (widget) => widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('command-tile-'),
    );
    expect(
      tester
          .widgetList<Widget>(tiles)
          .map((widget) => (widget.key! as ValueKey<String>).value.substring('command-tile-'.length)),
      unorderedEquals(ids),
    );
    for (final id in ids) {
      expect(find.byKey(ValueKey<String>('command-tile-$id')), findsOneWidget);
      final tile = tester.widget<CommandTile>(find.byKey(ValueKey<String>('command-tile-$id')));
      expect(tile.command, same(menu.commands.singleWhere((command) => command.id == id)));
    }
    await World.tapInView(tester, 'project-menu');
    for (final id in ids) {
      expect(find.byKey(ValueKey<String>(id)), findsOneWidget);
    }
  });
}
