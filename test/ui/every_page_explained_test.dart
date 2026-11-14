import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/page_words.dart';

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';

/// The kinds of page opened over the frame, each named; a new kind does not compile until it is named here.
String _kind(Opened opened) => switch (opened) {
  NothingOpened() => 'nothing',
  WorkOpened() => 'work',
  OperationOpened() => 'operation',
  GateOpened() => 'gate',
  EgressOpened() => 'egress',
  BackupsOpened() => 'backups',
  OperationsOpened() => 'operations',
  ReviewOpened() => 'review',
  LogOpened() => 'log',
};

/// The `i`s the window shows now, by their explanation's name.
List<String> _explained() => [
  for (final element in find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('explanation-open ');
  }).evaluate())
    (element.widget.key! as ValueKey<String>).value.substring('explanation-open '.length),
];

void main() {
  // Harm: a page ships with no way to learn what it is or what a person does there.
  testWidgets('every page the window shows has its i', (tester) async {
    await World.startBackend(World.work);
    final view = organizationFor('olive');
    await World.startApp(tester, organizationSource: FixtureOrganization(view));
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await World.settle(tester);
    final machine = World.machines.current;

    // Each place with the one i it shows, where that is not its own.
    final wrong = <String>[];
    Future<void> visit(String name, String id, void Function() go) async {
      World.shell.close();
      go();
      await World.settle(tester);
      final shown = _explained();
      if (shown.length != 1 || shown.single != id) wrong.add('$name shows $shown, not [$id]');
    }

    final sections = <Section>{};
    for (final section in Section.values) {
      sections.add(section);
      final id = switch (section) {
        Section.attention => 'needs-you',
        Section.organizations => 'organization',
        _ => section.name,
      };
      await visit('section ${section.name}', id, () {
        switch (section) {
          case Section.machine:
            World.shell.choosePlace(ShellPlace(Section.machine, machine: machine));
          case Section.project:
            World.fleet.selectProject('checkout');
            World.shell.openProject(machine, 'checkout');
          case Section.organization:
            World.shell.choosePlace(ShellPlace(Section.organization, organization: view.name));
          default:
            World.shell.goTo(section);
        }
      });
    }
    final machineSections = <MachineSection>{};
    for (final section in MachineSection.values) {
      machineSections.add(section);
      await visit(
        'machine ${section.name}',
        machineSectionPageId(section),
        () => World.shell.choosePlace(ShellPlace(Section.machine, machine: machine, machineSection: section)),
      );
    }
    final organizationSections = <OrganizationSection>{};
    for (final section in OrganizationSection.values) {
      organizationSections.add(section);
      await visit(
        'organization ${section.name}',
        'organization-${section.name}',
        () => World.shell.choosePlace(
          ShellPlace(Section.organization, organization: view.name, organizationSection: section),
        ),
      );
    }
    final operation = World.operations.run(title: 'Check', output: const Stream<Object>.empty(), machine: machine.name);
    World.fleet.selectTask(World.fleet.tasks.first.name);
    await World.gate.lookAt(World.backend, World.fleet.projects.first.project);
    await World.gate.look(World.backend, World.gate.waiting.first);
    final kinds = <String>{};
    for (final opened in <Opened>[
      const NothingOpened(),
      const WorkOpened(),
      OperationOpened(operation.id),
      const GateOpened(),
      const EgressOpened(),
      const BackupsOpened(),
      const OperationsOpened(),
      const ReviewOpened(),
      LogOpened(World.fleet.tasks.first.name, 'agent'),
    ]) {
      kinds.add(_kind(opened));
      if (opened is NothingOpened) continue;
      await visit('opened ${_kind(opened)}', openedPageId(opened), () {
        World.shell.goTo(Section.work);
        switch (opened) {
          case NothingOpened():
            break;
          case WorkOpened():
            World.shell.openDetail();
          case OperationOpened(:final id):
            World.shell.openOperation(id);
          case GateOpened():
            World.shell.openGate();
          case EgressOpened():
            World.shell.openEgress();
          case BackupsOpened():
            World.shell.openBackups();
          case OperationsOpened():
            World.shell.openOperations();
          case ReviewOpened():
            World.shell.openReview();
          case LogOpened(:final task, :final log):
            World.logs.open(World.fleet.backend, task, log);
            World.shell.openLog(task, log);
        }
      });
    }

    expect(sections, Section.values.toSet());
    expect(machineSections, MachineSection.values.toSet());
    expect(organizationSections, OrganizationSection.values.toSet());
    expect(kinds, {for (final opened in _all) _kind(opened)});
    expect(wrong, isEmpty);
  });
}

/// One of each kind, to compare the kinds visited with.
final _all = <Opened>[
  const NothingOpened(),
  const WorkOpened(),
  const OperationOpened(''),
  const GateOpened(),
  const EgressOpened(),
  const BackupsOpened(),
  const OperationsOpened(),
  const ReviewOpened(),
  const LogOpened('', ''),
];
