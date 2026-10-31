import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:porelo_frontend/src/app/templates.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/ui/projects_page.dart';
import 'package:porelo_frontend/src/ui/machine_details_page.dart';
import 'package:porelo_frontend/src/ui/start_work_view.dart';
import 'package:porelo_frontend/src/app/registry_pages.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';

import '../features/support/world.dart';

void main() {
  // Harm: a saved job hidden by its section must remain reachable for deliberate execution through the finder.
  testWidgets('finding a saved job reveals its filtered collapsed section and opens the row command', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    await World.templates.keep(
      const Template(name: 'Check API', project: 'checkout', agent: 'claude', mode: Mode.agent, prompt: ''),
    );
    final machine = World.machines.current;
    World.fleet.selectProject('checkout');
    World.shell.openProject(machine, 'checkout');
    await World.settle(tester);
    final identity = 'project-jobs ${machine.name}/checkout';
    await tester.enterText(find.byKey(ValueKey('$identity-filter')), 'no match');
    await World.settle(tester);
    await World.tapInView(tester, '$identity-fold');
    World.shell.show('template.start/checkout/Check API', section: Section.project);
    await World.settle(tester);
    expect(find.byKey(const Key('highlighted')), findsOneWidget);
    expect(find.byKey(const Key('job checkout/Check API')), findsOneWidget);
    expect(World.shell.highlight, isNull, reason: 'the row reports when its command has been shown');
    expect(tester.widget<PopupMenuItem<String>>(find.byKey(const Key('highlighted'))).enabled, isTrue);
    expect(World.fleet.selectedProject?.name, 'checkout');
    await tester.ensureVisible(find.byKey(const Key('highlighted')));
    await tester.tap(find.byKey(const Key('highlighted')));
    await World.settle(tester);
    expect(World.starting.project?.name, 'checkout');
    expect(find.byType(StartWorkDialog), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  // Harm: an unreported default project must still allow deliberate removal of its repositories.
  testWidgets('the default item page and finder retain repository management before the daemon lists default', (
    tester,
  ) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas.removeWhere((project) => project.name == defaultProject);
    World.backend.inDefault = [
      const DefaultRepository(
        name: 'api',
        upstream: 'https://forge.example.org/acme/api.git',
        checkout: '',
        claimedBy: '',
      ),
    ];
    await World.startApp(tester);
    final machine = World.machines.current;
    World.shell.goTo(Section.projects);
    await World.settle(tester);
    await World.tapInView(tester, 'project ${machine.name}/default');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await World.settle(tester);
    await tester.enterText(find.byKey(const Key('command-query')), 'Repositories worked on without a project');
    await World.settle(tester);
    final command = find.widgetWithText(ListTile, 'Repositories worked on without a project');
    expect(tester.widget<ListTile>(command).enabled, isTrue);
    await tester.tap(command);
    await World.settle(tester);
    await World.tapInView(tester, 'default-remove api');
    expect(World.backend.inDefault, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

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
