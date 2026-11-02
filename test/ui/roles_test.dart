import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/roles.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/command_finder.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';

import '../features/support/world.dart';
import '../support/host_organization.dart';

void main() {
  setUp(() => roles = const Roles());
  tearDown(() => roles = const Roles());

  for (final role in ['user', 'host-admin', 'access-admin']) {
    testWidgets('menus and the finder show only held roles ($role)', (tester) async {
      roles = Roles.fromArguments(['--roles', role]);
      tester.view
        ..physicalSize = const Size(1280, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final ran = <Role>[];
      final commands = [
        for (final role in [Role.user, Role.hostAdmin])
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
                ],
              ),
            ),
          ),
        ),
      );
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

  // Harm: a host admin finds Prepare a server… only by typing its name, never by pointing.
  for (final held in [true, false]) {
    testWidgets('the Machines page offers Prepare a server… to a host admin alone (${held ? 'held' : 'not held'})', (
      tester,
    ) async {
      if (held) roles = Roles.fromArguments(const ['--roles', 'host-admin']);
      await World.startBackend(World.work);
      await World.startApp(tester);
      World.shell.goTo(Section.machines);
      await World.settle(tester);
      final control = find.byKey(const Key('host.prepare'));
      expect(control, held ? findsOneWidget : findsNothing);
      // Without a read organization nobody is known as host admin yet, so it says why instead of opening.
      if (held) {
        expect(tester.widget<OutlinedButton>(control).onPressed, isNull);
        expect(
          find.ancestor(of: control, matching: find.byTooltip('The verified host admins are unavailable.')),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.byTooltip('Watch another machine…')),
        findsOneWidget,
      );
    });
  }

  // Harm: the app's host setup is composed without the host admin check, so a host admin named in owners.yml is
  // never let in, or anybody else is.
  for (final admin in [true, false]) {
    testWidgets('the shell gives host setup the composed host access (${admin ? 'host admin' : 'nobody named'})', (
      tester,
    ) async {
      roles = Roles.fromArguments(const ['--roles', 'host-admin']);
      final fixture = HostFixture()..admin = admin;
      await World.startBackend(World.work);
      await World.startApp(tester, hostAccess: fixture.access);
      World.shell.goTo(Section.machines);
      await World.settle(tester);
      final control = find.byKey(const Key('host.prepare'));
      expect(tester.widget<OutlinedButton>(control).onPressed, admin ? isNotNull : isNull);
      expect(
        find.ancestor(of: control, matching: find.byTooltip('The verified host admins are unavailable.')),
        findsNothing,
      );
    });
  }

  // Harm: a host admin whose identity read ends after the organization's is kept from Prepare until something else redraws.
  testWidgets('the shell shows Prepare a server… once a late identity read proves a host admin', (tester) async {
    roles = Roles.fromArguments(const ['--roles', 'host-admin']);
    final fixture = HostFixture();
    final proof = FixtureProof(fixture)..hold = Completer<void>();
    fixture.actor = null;
    await World.startBackend(World.work);
    await World.startApp(tester, hostAccess: (settings) => fixture.access(settings, proof: proof));
    World.shell.goTo(Section.machines);
    await World.settle(tester);
    final control = find.byKey(const Key('host.prepare'));
    expect(tester.widget<OutlinedButton>(control).onPressed, isNull);
    final late = proof.readAgain();
    proof.hold!.complete();
    await late;
    await World.settle(tester);
    expect(tester.widget<OutlinedButton>(control).onPressed, isNotNull);
  });
}
