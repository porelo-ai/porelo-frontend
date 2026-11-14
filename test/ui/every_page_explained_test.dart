import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/page_words.dart';
import 'package:porelo_host/porelo_host.dart' as host;

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

/// The explanation names of the keys starting with [prefix] the window shows now: its `i`s, or its open cards; with
/// [scrolledAway], also those its page's scroll has taken out of sight.
List<String> _keyed(String prefix, {bool scrolledAway = false}) => [
  for (final element in find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith(prefix);
  }, skipOffstage: !scrolledAway).evaluate())
    (element.widget.key! as ValueKey<String>).value.substring(prefix.length),
];

/// Visits places, each with the one explanation it should show, and gathers what is wrong with them.
class _Guard {
  _Guard(this.tester);

  final WidgetTester tester;

  /// What was wrong where.
  final wrong = <String>[];

  /// The explanations seen so far, which stand open only the first time.
  final _seen = <String>{};

  /// Goes to the place [name] by [go] and checks it shows the `i` of [id] alone, its card standing open the first
  /// time, and that the `i` opens that card again once it is folded; with [id] null, that it shows none.
  Future<void> visit(String name, String? id, FutureOr<void> Function() go) async {
    World.shell.close();
    await World.settle(tester);
    await go();
    await World.settle(tester);
    final shown = _keyed('explanation-open ');
    final open = _keyed('explanation-fold ');
    if (id == null) {
      if (shown.isNotEmpty || open.isNotEmpty) wrong.add('$name shows i $shown and cards $open, not none');
      return;
    }
    if (shown.length != 1 || shown.single != id) {
      wrong.add('$name shows i $shown, not [$id]');
      return;
    }
    final first = _seen.add(id);
    if (open.any((each) => each != id) || open.length > 1 || first && open.isEmpty) {
      wrong.add('$name shows cards $open, not [$id]${first ? ' standing open' : ''}');
      return;
    }
    if (open.isNotEmpty) {
      await _tap('explanation-fold $id');
    }
    final folded = _keyed('explanation-fold ', scrolledAway: true);
    if (folded.isNotEmpty) wrong.add('$name keeps $folded once folded');
    final left = _keyed('explanation-open ', scrolledAway: true);
    if (left.length != 1 || left.single != id) {
      wrong.add('$name shows i $left once folded, not [$id]');
      return;
    }
    await _tap('explanation-open $id');
    final again = _keyed('explanation-fold ');
    if (again.length != 1 || again.single != id) wrong.add('$name opens $again by its i, not [$id]');
  }

  /// Taps [key] once it is brought into the middle of its page, clear of anything at the window's edge.
  Future<void> _tap(String key) async {
    final found = find.byKey(ValueKey<String>(key), skipOffstage: false);
    await Scrollable.ensureVisible(tester.element(found), alignment: 0.5);
    await World.settle(tester);
    await tester.tap(found);
    await World.settle(tester);
  }
}

void main() {
  // Harm: a page ships with no way to learn what it is or what a person does there, or with two that say different
  // things, or with an i that opens nothing.
  testWidgets('every page the window shows has its one i, which opens its own words', (tester) async {
    await World.startBackend(World.work);
    final view = organizationFor('olive');
    await World.startApp(tester, organizationSource: FixtureOrganization(view));
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await World.settle(tester);
    final machine = World.machines.current;
    final guard = _Guard(tester);

    final sections = <Section>{};
    for (final section in Section.values) {
      sections.add(section);
      final id = switch (section) {
        Section.attention => 'needs-you',
        _ => section.name,
      };
      await guard.visit('section ${section.name}', id, () {
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
      await guard.visit(
        'machine ${section.name}',
        machineSectionPageId(section),
        () => World.shell.choosePlace(ShellPlace(Section.machine, machine: machine, machineSection: section)),
      );
    }
    final organizationSections = <OrganizationSection>{};
    for (final section in OrganizationSection.values) {
      organizationSections.add(section);
      await guard.visit(
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
      await guard.visit('opened ${_kind(opened)}', openedPageId(opened), () {
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

    // A page opened over a machine's section or a project's page is the page: the one beneath shows no i of its own.
    await guard.visit('operations over credentials', 'operations', () {
      World.shell.choosePlace(
        ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.credentials),
      );
      World.shell.openOperations();
    });
    await guard.visit('operations over projects', 'operations', () {
      World.shell.choosePlace(ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.projects));
      World.shell.openOperations();
    });
    await guard.visit('operations over a project', 'operations', () {
      World.fleet.selectProject('checkout');
      World.shell.openProject(machine, 'checkout');
      World.shell.openOperations();
    });
    // The terminals of running work fill the page, under no explanation.
    await guard.visit('machine tasks running', null, () async {
      World.shell.choosePlace(ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.tasks));
      await World.settle(tester);
      await World.tapInView(tester, 'work-view-running');
    });
    await World.tapInView(tester, 'work-view-list');

    expect(sections, Section.values.toSet());
    expect(machineSections, MachineSection.values.toSet());
    expect(organizationSections, OrganizationSection.values.toSet());
    expect(kinds, {for (final opened in _all) _kind(opened)});
    expect(guard.wrong, isEmpty);
  });

  // Harm: a machine an organization's card names, or an organization's project, shows no i, or one beside each list.
  testWidgets("an organization's machines and projects have their one i each", (tester) async {
    await World.startBackend(World.work);
    final view = organizationFor('hana');
    await World.startApp(
      tester,
      organizationSource: FixtureOrganization(view),
      hostConnections: FixtureConnections(['build']),
    );
    final card = host.HostCardSsh(
      name: 'build',
      address: buildHost.address!,
      sshPort: buildHost.port!,
      hostKey: buildHost.hostKey!,
      login: 'hana',
      publicKey: buildHost.hostKey!,
      webPort: buildHost.webPort,
    );
    final machine = Machine.fromHostCard(card, socketPath: '/unused');
    await World.machines.add(machine);
    await World.settle(tester);
    final guard = _Guard(tester);

    await guard.visit(
      'a machine with a card',
      'machine',
      () => World.shell.choosePlace(ShellPlace(Section.machine, machine: machine)),
    );
    expect(find.byKey(const ValueKey('organization-host build')), findsOneWidget);
    await guard.visit(
      'its Machine Admins',
      machineAdminsPageId,
      () => World.shell.choosePlace(
        ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.managing),
      ),
    );
    expect(find.byKey(const ValueKey('organization-host-admins build')), findsOneWidget);
    await guard.visit(
      'its projects',
      machineSectionPageId(MachineSection.projects),
      () => World.shell.choosePlace(
        ShellPlace(Section.machine, machine: machine, machineSection: MachineSection.projects),
      ),
    );
    // A machine of the organization this window does not hold opens as the organization's page of it.
    await guard.visit('a machine of the organization', 'machine', () async {
      World.shell.choosePlace(
        ShellPlace(Section.organization, organization: view.name, organizationSection: OrganizationSection.machines),
      );
      await World.settle(tester);
      await World.tapInView(tester, 'my-host spare');
    });
    expect(find.byKey(const ValueKey('organization-host spare')), findsOneWidget);
    await guard.visit('a project of the organization', 'organization-project', () async {
      World.shell.goTo(Section.projects);
      await World.settle(tester);
      await World.tapInView(tester, 'my-project other');
    });
    expect(find.byKey(const ValueKey('organization-project other')), findsOneWidget);

    expect(guard.wrong, isEmpty);
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
