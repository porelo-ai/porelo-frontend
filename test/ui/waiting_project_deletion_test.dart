import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../features/support/world.dart';

void main() {
  List<Project> heldProjects() => [
    for (final name in ['first', 'second'])
      Project.from({
        'name': name,
        'file': '/srv/$name/project.yml',
        'messages': {'waits': 'Messages cannot move.', 'waitsOn': 'vault'},
      }),
  ];

  Future<void> prepare(WidgetTester tester) async {
    await World.startBackend([]);
    World.backend.theProjectsItHas = heldProjects();
    await World.startApp(tester);
    World.elsewhere.theProjectsItHas = heldProjects();
    await World.machines.add(const Machine(name: 'elsewhere', socketPath: '/tmp/elsewhere.sock'));
    await World.machines.of(World.machines.all.last).untilAsked();
    World.shell.goTo(Section.attention);
    await World.settle(tester);
    for (final machine in World.machines.all) {
      expect(
        find.byKey(ValueKey('messages-wait ${machine.name}')),
        findsOneWidget,
        reason: 'both machines must have a row holding the two projects',
      );
    }
  }

  Finder stopFollowing(String machine, String project) => find.descendant(
    of: find.byKey(ValueKey('messages-wait $machine')),
    matching: find.widgetWithText(TextButton, 'Stop following $project…'),
  );

  // Harm: a row action could remove another project or another machine's unreviewed work without confirmation.
  testWidgets('held projects preview and remove only the chosen project on its own machine', (tester) async {
    await prepare(tester);
    final local = World.machines.all.first;
    for (final machine in World.machines.all) {
      for (final project in ['first', 'second']) {
        World.backend.deletions.clear();
        World.elsewhere.deletions.clear();
        final backend = machine == local ? World.backend : World.elsewhere;
        final other = machine == local ? World.elsewhere : World.backend;
        final button = stopFollowing(machine.name, project);
        expect(button, findsOneWidget, reason: 'each held project needs its own preview action');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await World.settle(tester);
        expect(backend.deletions, [
          (project: project, preview: true, force: false),
        ], reason: 'opening the preview must remove nothing and target only the chosen project');
        expect(other.deletions, isEmpty, reason: 'the other machine must receive no deletion call');
        expect(World.deleting.project, project, reason: 'the preview must describe the chosen project');
        await tester.tap(find.byKey(const Key('remove-what-was-built')));
        await World.settle(tester);
        expect(backend.deletions, [
          (project: project, preview: true, force: false),
          (project: project, preview: false, force: false),
        ], reason: 'only explicit confirmation may remove the chosen project');
        expect(other.deletions, isEmpty, reason: 'confirmation must stay on the preview machine');
        await tester.tap(find.widgetWithText(FilledButton, 'Right'));
        await World.settle(tester);
      }
    }
  });

  // Harm: canceling a preview must not remove a held project or its unreviewed work.
  testWidgets('leaving a held project preview never removes anything', (tester) async {
    await prepare(tester);
    final machine = World.machines.all.last;
    final button = stopFollowing(machine.name, 'second');
    expect(button, findsOneWidget, reason: 'the held project needs a preview action');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('leave-the-project-alone')));
    await World.settle(tester);
    expect(World.elsewhere.deletions, [
      (project: 'second', preview: true, force: false),
    ], reason: 'leaving the preview must make no destructive call');
    expect(World.backend.deletions, isEmpty, reason: 'the selected machine must remain untouched');
  });
}
