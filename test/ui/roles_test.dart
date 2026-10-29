import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/roles.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/command_finder.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';
import 'package:porelo_frontend/src/ui/machine_view.dart';

import '../features/support/world.dart';

void main() {
  setUp(() => roles = const Roles());
  tearDown(() => roles = const Roles());

  // Harm: ordinary project work offers a flow that rents and changes a server.
  testWidgets('the project menu omits server placement without startup roles', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    World.fleet.selectProject('checkout');
    World.shell.goTo(Section.project);
    await World.settle(tester);
    await World.tapInView(tester, 'project-menu');
    expect(find.text('Put this project on a server…'), findsNothing);
  });

  testWidgets('the project menu offers server placement to a project administrator', (tester) async {
    roles = Roles.fromArguments(const ['--roles', 'project-admin']);
    await World.startBackend(World.work);
    await World.startApp(tester);
    World.fleet.selectProject('checkout');
    World.shell.goTo(Section.project);
    await World.settle(tester);
    await World.tapInView(tester, 'project-menu');
    expect(
      find.descendant(
        of: find.byKey(const Key('project.server')),
        matching: find.text('Put this project on a server…'),
      ),
      findsOneWidget,
    );
  });

  for (final role in ['user', 'host-admin', 'project-admin', 'access-admin']) {
    testWidgets('menus, tiles and the finder show only held roles ($role)', (tester) async {
      roles = Roles.fromArguments(['--roles', role]);
      tester.view
        ..physicalSize = const Size(1280, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final ran = <Role>[];
      final commands = [
        for (final role in [Role.user, Role.hostAdmin, Role.projectAdmin])
          Command(id: role.name, label: role.name, group: 'Work', role: role, run: () => ran.add(role)),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  CommandMenu(commands: commands, tooltip: 'Commands'),
                  TextButton(
                    onPressed: () => showCommandMenu(context, Offset.zero, commands),
                    child: const Text('Context menu'),
                  ),
                  TextButton(onPressed: () => showCommandFinder(context, commands), child: const Text('Finder')),
                  for (final command in commands)
                    CommandTile(command: command, icon: Icons.play_circle_outline, description: command.label),
                ],
              ),
            ),
          ),
        ),
      );
      for (final command in commands) {
        expect(find.text(command.label), roles.holds(command.role) ? findsOneWidget : findsNothing);
      }
      await tester.tap(find.byTooltip('Commands'));
      await World.settle(tester);
      for (final command in commands) {
        expect(find.byKey(ValueKey(command.id)), roles.holds(command.role) ? findsOneWidget : findsNothing);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await World.settle(tester);
      await tester.tap(find.text('Context menu'));
      await World.settle(tester);
      for (final command in commands) {
        expect(find.byKey(ValueKey(command.id)), roles.holds(command.role) ? findsOneWidget : findsNothing);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await World.settle(tester);
      await tester.tap(find.text('Finder'));
      await World.settle(tester);
      for (final command in commands) {
        expect(
          find.descendant(of: find.byType(Dialog), matching: find.text(command.label)),
          roles.holds(command.role) ? findsOneWidget : findsNothing,
        );
      }
      expect(ran, isEmpty);
    });
  }
}
