import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/project_access.dart';
import 'package:porelo_frontend/src/app/roles.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/ui/shell.dart';

import '../features/step/the_project_has_the_repositories.dart';
import '../features/support/world.dart';
import '../support/project_access.dart';

void main() {
  setUp(() => roles = Roles.fromArguments(const ['--roles', 'project-admin']));
  tearDown(() => roles = const Roles());

  // Harm: a retained callback must act on the project whose availability was checked.
  // The project's persons are its page's list now, not a menu command.
  for (final commandId in ['project.server']) {
    testWidgets('$commandId keeps its project after selection changes', (tester) async {
      await World.startBackend(World.work);
      await World.startApp(tester);
      await theProjectHasTheRepositories(tester, 'checkout', 'checkout');
      World.fleet.selectProject('checkout');
      World.shell.goTo(Section.project);
      final fixture = ProjectAccessFixture();
      addTearDown(fixture.registry.dispose);
      final access = await fixture.access(World.settings);
      final old = tester.widget<Shell>(find.byType(Shell));
      await tester.pumpWidget(MaterialApp(home: _copy(old, (_) => access)));
      await World.settle(tester);
      await tester.tap(find.byTooltip('Find a command (Ctrl+K)'));
      await World.settle(tester);
      final dynamic finder = tester.widget(
        find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_CommandFinder'),
      );
      final commands = finder.commands as List<Command>;
      final command = commands.singleWhere((item) => item.id == commandId);
      Navigator.of(tester.element(find.byType(Dialog))).pop();
      await World.settle(tester);
      expect(command.available, isTrue);
      World.fleet.selectProject('default');
      command.run();
      await World.settle(tester);
      expect(find.text(commandId == 'project.server' ? 'Register checkout' : 'Persons in checkout'), findsOneWidget);
      expect(fixture.calls, isEmpty);
    });
  }
}

Shell _copy(Shell old, ProjectAccess? Function(String) access) => Shell(
  machines: old.machines,
  shell: old.shell,
  settings: old.settings,
  operations: old.operations,
  logs: old.logs,
  gate: old.gate,
  notifications: old.notifications,
  egress: old.egress,
  widening: old.widening,
  starting: old.starting,
  inventory: old.inventory,
  templates: old.templates,
  stopping: old.stopping,
  vault: old.vault,
  newerVersion: old.newerVersion,
  sessions: old.sessions,
  deleting: old.deleting,
  readiness: old.readiness,
  authentication: old.authentication,
  following: old.following,
  connections: old.connections,
  forges: old.forges,
  projectAccess: access,
  pickAFile: old.pickAFile,
  backups: old.backups,
  narrowing: old.narrowing,
  held: old.held,
);
