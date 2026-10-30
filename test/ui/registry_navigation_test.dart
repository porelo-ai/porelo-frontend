import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/ui/projects_page.dart';
import 'package:porelo_frontend/src/ui/machine_details_page.dart';
import 'package:porelo_frontend/src/app/registry_pages.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';

import '../features/support/world.dart';

void main() {
  // Harm: a machine page must never stop a different machine after current selection changes.
  testWidgets('a machine page refuses commands while a different machine is current', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    final first = World.machines.current;
    const second = Machine(name: 'elsewhere', socketPath: '/unused');
    await World.machines.add(second);
    World.shell.openMachine(first);
    await World.settle(tester);
    World.machines.select(second);
    await World.settle(tester);
    await World.tapInView(tester, 'machine-menu');
    final panic = tester.widget<PopupMenuItem<String>>(find.byKey(const Key('machine.panic')));
    expect(panic.enabled, isFalse);
    await World.tapInView(tester, 'machine.panic');
    expect(World.backend.panics, isEmpty);
    expect(World.elsewhere.panics, isEmpty);
  });

  // Harm: a default row on another machine can start work on the current machine instead.
  for (final size in [const Size(1280, 800), const Size(390, 844)]) {
    testWidgets('default rows keep their machine when filtered and opened at ${size.width}', (tester) async {
      await World.startBackend(World.work);
      await World.startApp(tester);
      const second = Machine(name: 'offline', socketPath: '/unused');
      await World.machines.add(second);
      World.elsewhere.absent = const VarlinkDisconnected('not connected');
      await World.machines.of(second).refresh(quietly: true);
      tester.view.physicalSize = size;
      final opened = <({Machine machine, String project})>[];
      final starts = <({Machine machine, String project})>[];
      final registry = RegistryPages();
      addTearDown(registry.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectsPage(
              machines: World.machines,
              registry: registry,
              muted: const {},
              onProject: (machine, project) => opened.add((machine: machine, project: project)),
              menuFor: (machine, project) => [
                Command(
                  id: 'work.start',
                  label: 'Start work',
                  group: 'Projects',
                  unavailable: machine == second ? 'This machine is not connected.' : null,
                  run: () => starts.add((machine: machine, project: project.name)),
                ),
              ],
              onFromARepository: null,
              onFollow: null,
            ),
          ),
        ),
      );
      await World.settle(tester);
      await tester.enterText(find.byKey(const Key('projects-filter')), 'Without a project');
      await World.settle(tester);
      expect(
        find.byWidgetPredicate((widget) => widget is Text && widget.data == 'Without a project'),
        findsNWidgets(2),
      );
      await tester.enterText(find.byKey(const Key('projects-filter')), 'offline');
      await World.settle(tester);
      await World.tapInView(tester, 'project offline/default');
      expect(opened, [(machine: second, project: defaultProject)]);
      await World.tapInView(tester, 'projects-menu offline/default');
      final start = tester.widget<PopupMenuItem<String>>(find.byKey(const Key('work.start')));
      expect(start.enabled, isFalse);
      expect(find.byKey(const Key('project.takeOffServer')), findsNothing);
      expect(starts, isEmpty);
      await tester.tapAt(const Offset(5, 5));
      await World.settle(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MachineDetailsPage(
              machine: second,
              machines: World.machines,
              registry: registry,
              commands: const [],
              onBack: () {},
              onProject: (project) => opened.add((machine: second, project: project)),
              projectCommands: (_) => const [],
            ),
          ),
        ),
      );
      await World.settle(tester);
      expect(find.text('Without a project'), findsOneWidget);
      final row = find.byKey(const Key('projects-menu offline/default'));
      final menu = tester.widget<CommandMenu>(row);
      expect(menu.commands.map((command) => command.label), ['Open']);
      expect(tester.takeException(), isNull);
    });
  }
}
