import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_host/porelo_host.dart' as host;
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/app/where_you_were.dart';
import 'package:porelo_frontend/src/ui/agents_view.dart';
import 'package:porelo_frontend/src/ui/attention_view.dart';
import 'package:porelo_frontend/src/ui/authentication_view.dart';
import 'package:porelo_frontend/src/ui/machine_details_page.dart';

import '../features/support/world.dart';
import '../features/support/tiles.dart';
import '../support/host_organization.dart';
import '../support/host_process.dart';
import '../support/organization_fixtures.dart';

String _parent(String name) => 'rail ${ShellPlace.machineKey(name)}';
String _leaf(String name, String section) => '${_parent(name)} $section';
Future<void> _tap(WidgetTester tester, String key) => World.tapInView(tester, key);

Future<void> _start(WidgetTester tester) async {
  await World.startBackend(World.work);
  await World.startApp(tester);
}

Future<HostPreparation> _preparation(WidgetTester tester) async {
  await World.startBackend(World.work);
  await World.startApp(tester, hostAccess: (settings) => HostFixture().access(settings));
  await toThePlace(tester, 'attention');
  final runs = tester.widget<AttentionView>(find.byType(AttentionView)).attention.hostRuns!;
  final process = HostProcess();
  final run = runs.start(
    project: 'orchard',
    session: HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process),
    record: const HostUpRecord(hostName: 'orchard', givenAddress: '203.0.113.7', givenHostKey: hostKey),
  );
  await World.settle(tester);
  process.line(const host.Step('install', host.StepState.refused, words: 'Stopped for the test'));
  process.end(65);
  await World.settle(tester);
  await run.finished;
  return run;
}

void main() {
  // Harm: removing the machine list strands a person on an unwanted or disconnected daemon.
  testWidgets('a watched remote machine can disconnect and reconnect from its facts', (tester) async {
    await _start(tester);
    const remote = Machine(name: 'elsewhere', socketPath: '/unused');
    await World.machines.add(remote);
    await toTheMachinesPage(tester, remote.name);
    await _tap(tester, 'machine-menu');
    await _tap(tester, 'machine.disconnect');
    expect(World.machines.all.singleWhere((machine) => machine.name == remote.name).disconnected, isTrue);
    await _tap(tester, 'machine-menu');
    await _tap(tester, 'machine.connect');
    expect(World.machines.all.singleWhere((machine) => machine.name == remote.name).disconnected, isFalse);
  });

  // Harm: a saved server cannot be repaired after its preparation controls disappear.
  testWidgets('a watched host keeps Run its setup again in its machine menu', (tester) async {
    await _start(tester);
    const machine = Machine(name: 'build', socketPath: '/unused', kind: 'host', hostProject: 'build');
    await World.settings.rememberHostUp(
      'build',
      const HostUpRecord(scalewayProject: 'provider', host: 'build', hostName: 'build', publicKey: '/keys/person.pub'),
    );
    await World.machines.add(machine);
    await toTheMachinesPage(tester, machine.name);
    await _tap(tester, 'machine-menu');
    expect(tester.widget<PopupMenuItem<String>>(find.byKey(const Key('host.again'))).enabled, isTrue);
  });

  // Harm: a stopped preparation loses its recovery and protocol, leaving a rented server running.
  for (final interrupted in [false, true]) {
    testWidgets('a ${interrupted ? 'interrupted' : 'failed'} preparation keeps recovery and protocol actions', (
      tester,
    ) async {
      final run = await _preparation(tester);
      if (interrupted) {
        run.interrupted = true;
        run.session.interrupt();
      }
      await toTheMachines(tester);
      await _tap(tester, _parent(run.name));
      expect(find.textContaining('Stopped'), findsWidgets);
      for (final id in [interrupted ? 'host.goOn' : 'host.retry', 'host.takeDown', 'host.protocol']) {
        expect(find.byKey(Key(id)), findsOneWidget);
      }
      await _tap(tester, 'host.protocol');
      expect(find.textContaining('Stopped for the test'), findsWidgets);
    });
  }

  // Harm: host-card administration disappears for a host as soon as it connects.
  for (final route in ['row', 'node', 'managing']) {
    testWidgets('a connected organization host keeps its host page through $route', (tester) async {
      await World.startBackend(World.work);
      final source = FixtureOrganization(organizationFor('mia'));
      await World.startApp(tester, organizationSource: source, hostConnections: FixtureConnections(['build']));
      final card = host.HostCardSsh(
        name: 'build',
        address: buildHost.address!,
        sshPort: buildHost.port!,
        hostKey: buildHost.hostKey!,
        login: 'mia',
        publicKey: buildHost.hostKey!,
      );
      final machine = Machine.fromHostCard(card, socketPath: '/unused');
      await World.machines.add(machine);
      await World.settle(tester);
      if (route == 'row') {
        await toTheOrganization(tester, section: OrganizationSection.machines);
        await _tap(tester, 'my-host build');
      } else {
        await toTheMachines(tester);
        await _tap(tester, _parent(machine.name));
        if (route == 'managing') await _tap(tester, _leaf(machine.name, 'managing'));
      }
      if (route == 'managing') {
        // A machine with a card is managed by its Machine Admins: the leaf is their list, not the machine's page again.
        expect(find.byKey(const Key('organization-host-admins build')), findsOneWidget);
        expect(find.text('hana'), findsOneWidget);
        expect(find.byKey(const Key('organization-host build')), findsNothing);
        return;
      }
      expect(find.byKey(const Key('organization-host build')), findsOneWidget);
      expect(find.byKey(const ValueKey('organization.openForge/build')), findsOneWidget, reason: 'a button in sight');
    });
  }

  // Harm: a new person cannot create the card required to join or create an organization.
  testWidgets('no organization still offers Make my card and opens its dialog', (tester) async {
    await World.startBackend(World.work);
    final source = FixtureOrganization(organizationFor('mia'))
      ..refuseReads = const OrganizationRefused('No organization', reason: 'no-organization');
    await World.startApp(tester, organizationSource: source);
    await toThePlace(tester, 'organizations');
    await _tap(tester, 'makeCard');
    expect(find.byType(Dialog), findsWidgets);
    expect(find.text('Make my card'), findsWidgets);
  });

  // Harm: malformed settings crash the tree or restore a page without its owner.
  for (final saved in <Map<String, Object?>>[
    {'section': 'organization', 'organizationSection': 'people'},
    {'section': 'organization', 'organization': 42, 'organizationSection': 'people'},
    {'section': 'work', 'organizationSection': 'people'},
    {
      'section': 'project',
      'machine': 'gone',
      'folded': ['machines', 'machine gone'],
    },
    {
      'section': 'machine',
      'machine': 'gone',
      'folded': ['machines', 'machine gone'],
    },
    {
      'section': 'invalid',
      'folded': ['machine gone'],
    },
    {},
  ]) {
    testWidgets('invalid navigation ${saved.toString()} restores a visible safe place and notifies', (tester) async {
      const current = Machine(name: 'current', socketPath: '/unused');
      final shell = ShellModel();
      addTearDown(shell.dispose);
      var notifications = 0;
      shell.addListener(() => notifications++);
      shell.initializeNavigation(current);
      shell.restoreNavigation(saved, [current], current);
      expect(() => shell.place.ancestors, returnsNormally);
      expect(shell.place.section, Section.work);
      expect(shell.foldedOpen, contains(ShellPlace.machineKey(current.name)));
      expect(shell.foldedOpen, isNot(contains('machine gone')));
      expect(notifications, greaterThan(0));
    });
  }

  // Harm: a removed organization leaves a stale name and no selected navigation row.
  testWidgets('a restored gone organization falls back after the loaded organization answers', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester, organizationSource: FixtureOrganization(organizationFor('mia')));
    World.shell.choosePlace(const ShellPlace(Section.organization, organization: 'gone'));
    await _tap(tester, 'refresh-all');
    expect(World.shell.place.section, Section.organizations);
    expect(find.text('gone'), findsNothing);
    expect(find.byKey(const Key('rail organizations')), findsOneWidget);
  });

  // Harm: choosing Work before quitting silently discards valid organization folds.
  testWidgets('Work preserves an expanded organization across a restart', (tester) async {
    const current = Machine(name: 'current', socketPath: '/unused');
    final shell = ShellModel();
    addTearDown(shell.dispose);
    final organization = ShellPlace.organizationKey('acme');
    shell.restoreNavigation(
      {
        'section': 'work',
        'folded': ['machines', ShellPlace.machineKey(current.name), 'organizations', organization],
      },
      [current],
      current,
    );
    expect(shell.place.section, Section.work);
    expect(shell.foldedOpen, contains(organization));
  });

  // Harm: the person chooses Planning while the window starts, and the first read of the machines takes them back to
  // the place saved before (runs 15 and 19 of F492).
  testWidgets('a place the person chose before the machines loaded stands over the saved one', (tester) async {
    const current = Machine(name: 'current', socketPath: '/unused');
    final shell = ShellModel();
    addTearDown(shell.dispose);
    shell.initializeNavigation(current);
    shell.choosePlace(const ShellPlace(Section.planning));
    shell.restoreNavigation({'section': 'work'}, [current], current);
    expect(shell.place.section, Section.planning);
    expect(shell.section, Section.planning);
    expect(shell.foldedOpen, contains(ShellPlace.machineKey(current.name)));
  });

  // Harm: a command the person found with the finder while the window starts is replaced by the place saved before.
  testWidgets('a place the finder showed before the machines loaded stands over the saved one', (tester) async {
    const current = Machine(name: 'current', socketPath: '/unused');
    final shell = ShellModel();
    addTearDown(shell.dispose);
    shell.initializeNavigation(current);
    shell.show('a command', section: Section.planning);
    shell.restoreNavigation({'section': 'work'}, [current], current);
    expect(shell.place.section, Section.planning);
  });

  // Harm: the person chose Work while the window started, and the restore selects the saved machine, project and
  // task under it anyway, so Work opens on a selection the person never made.
  testWidgets('a place chosen before the restore keeps the saved selection away', (tester) async {
    final settings = Settings(
      MemorySettingsStore({
        'machines': [
          const Machine(name: 'chosen', socketPath: '/unused').stored,
          const Machine(name: 'loaded', socketPath: '/unused').stored,
        ],
      }),
    );
    await settings.load();
    await settings.rememberWhereYouWere({'machine': 'loaded', 'project': 'saved-project'});
    final machines = Machines(settings, reach: (_) => FakeBackend([]), tunnels: FakeTunnels());
    final shell = ShellModel();
    final restoration = WhereYouWere(settings, machines, shell);
    addTearDown(restoration.dispose);
    addTearDown(machines.dispose);
    addTearDown(shell.dispose);
    addTearDown(settings.dispose);
    await machines.load();
    expect(machines.current.name, 'chosen');
    shell.choosePlace(const ShellPlace(Section.work));
    await restoration.restore();
    expect(shell.place.section, Section.work);
    expect(machines.current.name, 'chosen');
  });

  // Harm: a second restoration silently changes nothing without letting the window redraw.
  testWidgets('an already restored navigation still notifies its listeners', (tester) async {
    const current = Machine(name: 'current', socketPath: '/unused');
    final shell = ShellModel();
    addTearDown(shell.dispose);
    shell.restoreNavigation({}, [current], current);
    var notified = false;
    shell.addListener(() => notified = true);
    shell.restoreNavigation({}, [current], current);
    expect(notified, isTrue);
  });

  // Harm: startup persists a stand-in before the saved current machine has loaded.
  testWidgets('first start waits for loading and unfolds the restored current machine', (tester) async {
    final settings = Settings(
      MemorySettingsStore({
        'machines': [const Machine(name: 'loaded', socketPath: '/unused').stored],
      }),
    );
    await settings.load();
    await settings.rememberWhereYouWere({'machine': 'loaded'});
    final machines = Machines(settings, reach: (_) => FakeBackend([]), tunnels: FakeTunnels());
    final shell = ShellModel();
    final restoration = WhereYouWere(settings, machines, shell);
    addTearDown(restoration.dispose);
    addTearDown(machines.dispose);
    addTearDown(shell.dispose);
    addTearDown(settings.dispose);
    await machines.load();
    expect(settings.shellNavigation, isEmpty, reason: 'loading cannot overwrite a saved selection');
    await restoration.restore();
    expect(machines.current.name, 'loaded');
    expect(shell.foldedOpen, contains(ShellPlace.machineKey('loaded')));
    expect(shell.foldedOpen, {'machines', ShellPlace.machineKey('loaded')});
    expect(settings.shellNavigation['folded'], contains(ShellPlace.machineKey('loaded')));
  });

  // Harm: the finder hides the destination of the command it just revealed.
  testWidgets('the finder opens an organization command without folding its chosen branch', (tester) async {
    await World.startBackend(World.work);
    final source = FixtureOrganization(organizationFor('mia'));
    await World.startApp(tester, organizationSource: source);
    await toThePlace(tester, 'organizations');
    final parent = 'rail ${ShellPlace.organizationKey(source.view.name)}';
    await _tap(tester, parent);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await World.settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Choose another Porelo organization');
    await World.settle(tester);
    await tester.tap(inTheFinder('Choose another Porelo organization…'));
    await World.settle(tester);
    expect(find.byKey(ValueKey('$parent people')), findsOneWidget);
    expect(find.byKey(const Key('highlighted')), findsOneWidget);
  });

  // Harm: a preparing machine exposes tools which actually operate on another machine.
  testWidgets('a preparing machine exposes no daemon tool leaves or shortcuts for another machine', (tester) async {
    final run = await _preparation(tester);
    final current = World.machines.current;
    await toTheMachines(tester);
    await _tap(tester, _parent(run.name));
    for (final section in MachineSection.values) {
      expect(find.byKey(ValueKey(_leaf(run.name, section.name))), findsNothing);
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await World.settle(tester);
    expect(find.byKey(const Key('new-work-project')), findsNothing);
    expect(find.byType(Dialog), findsNothing);
    expect(World.backend.starts, isEmpty);
    expect(World.machines.current, current);
  });

  // Harm: an always-listed but unwatched local node exposes another daemon's tools.
  testWidgets('an unwatched local node has no daemon section leaves', (tester) async {
    await _start(tester);
    final local = World.machines.current;
    const remote = Machine(name: 'elsewhere', socketPath: '/unused');
    await World.machines.add(remote);
    World.machines.select(remote);
    await World.machines.forget(local);
    await toTheMachines(tester);
    await _tap(tester, _parent(local.name));
    for (final section in MachineSection.values) {
      expect(find.byKey(ValueKey(_leaf(local.name, section.name))), findsNothing);
    }
    expect(World.machines.current, remote);
    expect(World.elsewhere.starts, isEmpty);
  });

  // Harm: unread observations are presented as an empty, healthy system.
  testWidgets('an unloaded forge list shows unknown even while idle', (tester) async {
    await _start(tester);
    World.forges.loaded = false;
    await toThePlace(tester, 'machines');
    expect(tester.widget<Text>(find.byKey(const Key('rail-forges-count'))).data, '?');
  });

  testWidgets('running and needing are unknown before any machine has answered', (tester) async {
    await _start(tester);
    final reply = Completer<void>();
    World.backend.answersLater = reply;
    await World.restartApp(tester);
    expect(find.descendant(of: find.byKey(const Key('rail work')), matching: find.text('?')), findsWidgets);
    expect(find.descendant(of: find.byKey(const Key('rail attention')), matching: find.text('?')), findsOneWidget);
    expect(find.byTooltip('0 running'), findsNothing);
    reply.complete();
    await World.settle(tester);
  });

  // Harm: closing a tool shows another page while the tree still names the tool.
  for (final leaf in ['vault', 'credentials', 'agents', 'health']) {
    testWidgets('closing $leaf returns to the named machine facts and selects its parent', (tester) async {
      await _start(tester);
      final machine = World.machines.current;
      await _tap(tester, _leaf(machine.name, leaf));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await World.settle(tester);
      expect(find.byKey(const Key('facts-page')), findsOneWidget);
      expect(find.byType(MachineDetailsPage), findsNothing);
      expect(World.shell.place.machine, machine);
      expect(World.shell.place.machineSection, isNull);
    });
  }

  // Harm: the combined agents leaf hides the provider settings needed to use an agent.
  testWidgets('Agents and providers reaches the providers view from the agents leaf', (tester) async {
    await _start(tester);
    await _tap(tester, _leaf(World.machines.current.name, 'agents'));
    expect(find.byType(AgentsView), findsOneWidget);
    await _tap(tester, 'machine.providers');
    expect(find.byType(AuthenticationView), findsOneWidget);
  });
}
