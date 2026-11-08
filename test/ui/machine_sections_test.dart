import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/device_key.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';
import 'package:porelo_frontend/src/ui/authentication_view.dart';
import 'package:porelo_frontend/src/ui/agents_view.dart';
import 'package:porelo_frontend/src/ui/connections_view.dart';
import 'package:porelo_frontend/src/ui/destinations_view.dart';
import 'package:porelo_frontend/src/ui/host_readiness_view.dart';
import 'package:porelo_frontend/src/ui/vault_view.dart';
import 'package:porelo_frontend/src/ui/vault_actions.dart';
import 'package:porelo_frontend/src/ui/operations.dart';
import 'package:porelo_frontend/src/ui/page_explanation.dart';
import 'package:porelo_frontend/src/ui/work_page.dart';
import 'package:porelo_frontend/src/ui/expandable_list_row.dart';
import 'package:porelo_frontend/src/ui/filtered_list_section.dart';
import 'package:porelo_frontend/src/ui/panes.dart';

import '../features/support/tiles.dart';
import '../features/support/world.dart';
import '../features/step/i_choose_the_command.dart';
import '../support/organization_fixtures.dart';

const _second = Machine(
  name: 'elsewhere',
  socketPath: '/unused',
  host: 'runner@second.example.org',
  remoteSocket: '/run/user/1000/porelo/porelod.sock',
);

Future<Machine> _start(WidgetTester tester, {FakeBackend? secondBackend, OrganizationSource? organization}) async {
  await World.startBackend(World.work);
  await World.startApp(tester, organizationSource: organization);
  final first = World.machines.current;
  if (secondBackend != null) {
    World.elsewhere = secondBackend;
    addTearDown(secondBackend.stop);
  }
  World.elsewhere.theStoreIs = VaultState.from(const {
    'vault': '/unused',
    'exists': true,
    'readable': true,
    'credentials': [
      {'name': 'second-entry', 'type': 'api-key', 'characters': 24, 'value': 'never-render-this-value'},
    ],
  });
  World.elsewhere.theConnections = [const Connection(match: 'second.example.org')];
  World.elsewhere.theAgentsItHas = [
    Agent.from(const {'name': 'second-agent', 'label': 'Second agent'}),
  ];
  World.elsewhere.theProvidersItHas = const Providers(
    readable: true,
    providers: [
      Provider(
        name: 'second-provider',
        label: 'Second provider',
        upstream: 'second.example.org',
        dialects: [],
        authenticated: false,
        credentialType: '',
        credentialName: '',
        storeCommand: '',
      ),
    ],
  );
  World.elsewhere.theHealthItReports = const Health(
    ready: false,
    probes: [Probe(name: 'second-probe', state: 'MISSING', detail: 'Second machine', action: 'Install it there')],
  );
  await World.machines.add(_second);
  World.machines.select(first);
  await World.settle(tester);
  return first;
}

Future<void> _open(WidgetTester tester, MachineSection section) async {
  await toTheMachines(tester);
  await World.tapInView(tester, 'rail ${ShellPlace.machineKey(_second.name)}');
  await World.tapInView(tester, 'rail ${ShellPlace.machineKey(_second.name)} ${section.name}');
}

void main() {
  // Harm: a machine's tasks read as all work, so a person stops or starts work on the wrong machine.
  testWidgets("a machine's Tasks leaf names its path, its title and that machine's tasks", (tester) async {
    final first = await _start(tester);
    await _open(tester, MachineSection.tasks);
    World.machines.select(first);
    await World.settle(tester);
    final head = find.byType(PageHead);
    expect(head, findsOneWidget, reason: 'one head, never a second one over the list');
    expect(tester.widget<Text>(find.descendant(of: head, matching: find.byKey(const Key('leaf-title')))).data, 'Tasks');
    expect(find.descendant(of: head, matching: find.text('Work')), findsNothing);
    final path = find.descendant(of: head, matching: find.byKey(ValueKey('machine-section-path ${_second.name}')));
    expect(path, findsOneWidget);
    for (final step in ['My machines', _second.name, 'Tasks']) {
      expect(
        find.descendant(of: path, matching: find.text(step)),
        findsOneWidget,
        reason: step,
      );
    }
    final tiles = find
        .byWidgetPredicate(
          (widget) => widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('tile '),
        )
        .evaluate()
        .map((element) => (element.widget.key! as ValueKey<String>).value)
        .toSet();
    expect(tiles, isNotEmpty);
    expect(tiles.every((key) => key.startsWith('tile ${_second.name} ')), isTrue, reason: '$tiles');
    expect(
      tester.widget<Text>(find.byKey(const Key('work-list-subtitle'))).data,
      startsWith('${tiles.length} ${tiles.length == 1 ? 'task' : 'tasks'} · '),
    );
  });

  // Harm: a directly restored managing page never reads the vault of the machine it names.
  testWidgets('Managing reads its own vault without selecting its machine', (tester) async {
    final first = await _start(tester);
    final before = World.backend.storeAsked.length;
    World.shell.choosePlace(
      const ShellPlace(Section.machine, machine: _second, machineSection: MachineSection.managing),
    );
    await World.settle(tester);
    expect(World.elsewhere.storeAsked, contains('credentials'));
    expect(World.backend.storeAsked.length, before);
    final vaultTile = find.byKey(const ValueKey('managing-tile vault'));
    expect(
      tester.widget<Text>(find.descendant(of: vaultTile, matching: find.byKey(const Key('tile-value')))).data,
      'Open',
    );
    expect(
      tester.widget<Text>(find.descendant(of: vaultTile, matching: find.byKey(const Key('tile-detail')))).data,
      '1 entry',
    );
    // The page's actions open and shut the vault; no lone lock stands beside them.
    expect(find.byType(VaultButtons), findsNothing);
    expect(World.machines.current, first);
  });

  // Harm: an emergency action becomes disabled or stops the title-bar machine instead of its leaf.
  testWidgets('Managing can panic its own machine while another is current', (tester) async {
    final first = await _start(tester);
    await _open(tester, MachineSection.managing);
    World.machines.select(first);
    await World.settle(tester);
    await World.tapInView(tester, 'machine.panic');
    await World.tapInView(tester, 'stop-it-all');
    expect(World.elsewhere.panics, [true, false]);
    expect(World.backend.panics, isEmpty);
    expect(World.machines.current, first);
  });

  // Harm: a scoped keyboard command is disabled or refreshes the title-bar machine instead.
  testWidgets('Managing refresh shortcut reaches its own machine', (tester) async {
    final first = await _start(tester);
    await _open(tester, MachineSection.managing);
    World.machines.select(first);
    await World.settle(tester);
    final ownBefore = World.elsewhere.projectsListed;
    final firstBefore = World.backend.projectsListed;
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await World.settle(tester);
    expect(World.elsewhere.projectsListed, greaterThan(ownBefore));
    expect(World.backend.projectsListed, firstBefore);
    expect(World.machines.current, first);
  });

  // Harm: the finder reveals a leaf command on a different machine's facts and executes it there.
  testWidgets('the finder keeps a managing command on the leaf machine', (tester) async {
    final first = await _start(tester);
    await _open(tester, MachineSection.managing);
    World.machines.select(first);
    await World.settle(tester);
    final ownBefore = World.elsewhere.healthAsked;
    final firstBefore = World.backend.healthAsked;
    await iChooseTheCommand(tester, 'Check whether this machine can run anything');
    expect(World.elsewhere.healthAsked, ownBefore + 1);
    expect(World.backend.healthAsked, firstBefore);
    expect(World.shell.place.machine, _second);
    expect(World.machines.current, first);
  });

  // Harm: scoped daemon checks or destructive previews are refused or sent to a different machine.
  for (final id in ['machine.doctor', 'machine.clear', 'fleet.refresh']) {
    testWidgets('Managing runs $id on its own machine while another is current', (tester) async {
      final first = await _start(tester);
      await _open(tester, MachineSection.managing);
      World.machines.select(first);
      await World.settle(tester);
      final firstHealth = World.backend.healthAsked;
      final ownHealth = World.elsewhere.healthAsked;
      final firstProjects = World.backend.projectsListed;
      final ownProjects = World.elsewhere.projectsListed;
      await World.tapInView(tester, id);
      switch (id) {
        case 'machine.doctor':
          expect(World.elsewhere.healthAsked, ownHealth + 1);
          expect(World.backend.healthAsked, firstHealth);
        case 'machine.clear':
          expect(World.elsewhere.clears, [(project: null, dryRun: true, force: false)]);
          expect(World.backend.clears, isEmpty);
        case 'fleet.refresh':
          expect(World.elsewhere.projectsListed, greaterThan(ownProjects));
          expect(World.backend.projectsListed, firstProjects);
      }
      expect(World.machines.current, first);
    });
  }

  // Harm: the vault's header/menu or the managing page changes or opens another machine's vault.
  for (final section in [MachineSection.managing, MachineSection.vault]) {
    for (final state in ['open', 'locked', 'missing']) {
      testWidgets('${section.name} acts on its own $state vault while another machine is current', (tester) async {
        final first = await _start(tester);
        World.elsewhere.theStoreIs = VaultState(
          vault: '/unused',
          exists: state != 'missing',
          readable: state != 'locked',
          credentials: const [],
        );
        await _open(tester, section);
        World.machines.select(first);
        await World.settle(tester);
        if (state == 'open') {
          if (section == MachineSection.vault) await World.tapInView(tester, 'vault-actions');
          await World.tapInView(tester, 'vault.shut');
          await World.tapInView(tester, 'vault-confirm');
          expect(World.elsewhere.storeAsked, contains('lock'));
          expect(World.backend.storeAsked, isNot(contains('lock')));
        } else {
          await World.tapInView(tester, state == 'missing' ? 'vault.make' : 'vault.passphrase');
          expect(World.terminals, isNotEmpty);
          expect(World.terminals.last.command, contains(_second.host));
        }
        expect(World.machines.current, first);
      });
    }
  }

  // Harm: forgetting a leaf removes the selected machine rather than the machine being managed.
  testWidgets('Managing forgets its own machine while another is current', (tester) async {
    final first = await _start(tester);
    await _open(tester, MachineSection.managing);
    World.machines.select(first);
    await World.settle(tester);
    await World.tapInView(tester, 'machine-menu');
    await World.tapInView(tester, 'machine.forget');
    await World.tapInView(tester, 'forget-it');
    expect(World.machines.all, [first]);
  });

  // Harm: forgotten machines retain listeners and credentials, then reuse stale data when re-added.
  testWidgets('forgetting a machine releases its models and readding starts without its old rows', (tester) async {
    await _start(tester);
    await _open(tester, MachineSection.vault);
    final vault = tester.widget<VaultView>(find.byType(VaultView)).vault;
    await _open(tester, MachineSection.credentials);
    final connections = tester.widget<ConnectionsView>(find.byType(ConnectionsView)).connections;
    await _open(tester, MachineSection.agents);
    final providers = tester.widget<AuthenticationView>(find.byType(AuthenticationView)).authentication;
    final inventory = tester.widget<AgentsView>(find.byType(AgentsView)).inventory;
    await _open(tester, MachineSection.health);
    final readiness = tester.widget<HostReadinessView>(find.byType(HostReadinessView)).readiness;
    await toTheMachines(tester);
    await World.machines.forget(_second);
    await World.settle(tester);
    for (final model in [vault, vault.devices, connections, providers, inventory, readiness]) {
      expect(() => model.addListener(() {}), throwsFlutterError, reason: 'a forgotten machine releases its notifiers');
    }
    World.elsewhere.credentialsTake = const Duration(seconds: 10);
    await World.machines.add(_second);
    await _open(tester, MachineSection.vault);
    expect(find.text('second-entry'), findsNothing);
    await tester.pump(const Duration(seconds: 11));
    await World.settle(tester);
    expect(find.text('second-entry'), findsOneWidget);
  });

  // Harm: a refresh resumes after the frame closes and starts a read on disposed tool models.
  testWidgets('a refresh that outlives the frame does not reuse disposed tools', (tester) async {
    final backend = _WaitingRefreshBackend();
    await _start(tester, secondBackend: backend);
    await _open(tester, MachineSection.vault);
    final projects = await backend.projects();
    backend.waitForProjects = Completer<List<Project>>();
    await World.tapInView(tester, 'refresh-all');
    expect(backend.refreshWaiting, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    backend.waitForProjects!.complete(projects);
    await World.settle(tester);
    expect(tester.takeException(), isNull);
  });

  // Harm: an offline or differently selected leaf strands overlays behind disabled page contents.
  for (final offline in [false, true]) {
    for (final differentCurrent in [false, true]) {
      testWidgets('section operations work with offline=$offline and different current=$differentCurrent', (
        tester,
      ) async {
        final first = await _start(tester);
        await _open(tester, MachineSection.vault);
        World.operations.run(
          title: 'Only the leaf action',
          machine: _second.name,
          output: Stream<String>.fromIterable(['Leaf output']),
        );
        World.operations.run(
          title: 'Only the current action',
          machine: first.name,
          output: Stream<String>.fromIterable(['Current output']),
        );
        if (offline) {
          World.elsewhere.absent = const VarlinkDisconnected('gone');
          World.elsewhere.lose();
        }
        if (differentCurrent) World.machines.select(first);
        await World.settle(tester);
        await World.tapInView(tester, 'operations-indicator');
        expect(find.byType(OperationsList), findsOneWidget);
        expect(find.text('Only the leaf action'), findsOneWidget);
        expect(find.text('Only the current action'), findsNothing);
        await tester.tap(find.byTooltip('Close (Esc)').hitTestable());
        await World.settle(tester);
        expect(find.byType(OperationsList), findsNothing);
        expect(World.shell.opened, isA<NothingOpened>());
      });
    }
  }

  // Harm: a refusal on another machine tears down the terminal still visible on this Tasks leaf.
  testWidgets('Running keeps its terminal when only the current machine has a refusal', (tester) async {
    final first = await _start(tester);
    await World.machines.of(first).removeWork('porelo-checkout-shell');
    expect(World.machines.of(first).refusal, isNotNull);
    await _open(tester, MachineSection.tasks);
    await World.tapInView(tester, 'work-view-running');
    expect(World.sessions.current?.machine, _second);
    final terminal = World.terminals.last;
    World.machines.select(first);
    await World.settle(tester);
    final view = tester.widget<WorkPage>(find.byType(WorkPage)).view;
    view.moveToTab('${_second.name}/porelo-shared-shell');
    await World.settle(tester);
    expect(terminal.closed, isFalse);
    expect(World.sessions.current?.machine, _second);
  });

  // Harm: a start dialog offers one machine's device enrollment but unlocks a different machine.
  testWidgets('a start dialog unlocks the machine whose device enrollment it offered', (tester) async {
    final first = await _start(tester);
    const slot = Keyslot(
      id: 'leaf-device',
      name: 'test device',
      storage: KeyslotStorage.userScoped,
      enrolled: '',
      lastUsed: '',
      self: false,
      recovery: false,
    );
    World.elsewhere.keyslotsHeld.add((slot: slot, share: 'test-share'));
    await World.keys.write(World.elsewhere.nodeId, const DeviceKey(slot: 'leaf-device', share: 'test-share'));
    World.elsewhere.nextReadiness = const Readiness(
      ready: false,
      outcome: StartOutcome.vaultLocked,
      agent: 'second-agent',
      provider: 'second-provider',
      credential: 'second-entry',
      detail: 'Locked',
    );
    await _open(tester, MachineSection.vault);
    await _open(tester, MachineSection.tasks);
    await World.tapInView(tester, 'new-work');
    await World.tapInView(tester, 'new-work-in checkout');
    World.starting.chooseAgent('second-agent');
    await World.settle(tester);
    World.machines.select(first);
    await World.settle(tester);
    await World.tapInView(tester, 'open-with-this-device');
    await World.chooseWords(tester, 'for an hour');
    await World.tapInView(tester, 'vault-confirm');
    expect(World.elsewhere.unlocksFor, [60]);
    expect(World.backend.unlocksFor, isEmpty);
    expect(World.machines.current, first);
  });

  // Harm: an unopened socket is used by a leaf and escapes as an unhandled StateError.
  for (final section in MachineSection.values) {
    testWidgets('a never-connected machine can open ${section.name} without asking an unopened socket', (tester) async {
      final backend = _GuardedBackend()..absent = const VarlinkDisconnected('No daemon');
      await _start(tester, secondBackend: backend);
      await _open(tester, section);
      expect(find.textContaining('does not answer'), findsWidgets);
      expect(backend.toolReads, 0);
      expect(tester.takeException(), isNull);
    });
  }

  // Harm: retrying a lost machine leaves its destination list unread and its commands stranded.
  testWidgets('Credentials retries its destinations once the machine answers', (tester) async {
    final backend = _GuardedBackend()..absent = const VarlinkDisconnected('No daemon');
    backend.destinationsHere.add(
      Destination.from(const {
        'name': 'second-destination',
        'label': 'Second destination',
        'upstream': 'https://second.example.org',
      }),
    );
    await _start(tester, secondBackend: backend);
    await _open(tester, MachineSection.credentials);
    expect(backend.destinationReads, 0);
    backend.absent = null;
    await World.tapInView(tester, 'machine-section-retry');
    expect(backend.destinationReads, greaterThan(0));
    expect(find.textContaining('Second destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Harm: leaving the frame while a remote read waits crashes on its late notification.
  testWidgets('a machine section can finish its read after the frame closes', (tester) async {
    await _start(tester);
    World.elsewhere.credentialsTake = const Duration(seconds: 10);
    await _open(tester, MachineSection.vault);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
    expect(tester.takeException(), isNull);
  });

  // Harm: losing contact erases the last health checks or presents them as current health.
  testWidgets('Health retains its last checks under an offline warning', (tester) async {
    await _start(tester);
    await _open(tester, MachineSection.health);
    World.elsewhere.absent = const VarlinkDisconnected('No daemon');
    World.elsewhere.lose();
    await World.settle(tester);
    await _open(tester, MachineSection.health);
    expect(find.textContaining('does not answer'), findsWidgets);
    expect(find.text('Second machine'), findsOneWidget);
    expect(find.textContaining('Read '), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  // Harm: restoring a leaf reassigns supplied observations from another machine to that leaf.
  testWidgets("a restored machine leaf cannot inherit another machine's supplied vault", (tester) async {
    final first = await _start(tester);
    await World.vault.lookAt(World.backend, first.name);
    await _open(tester, MachineSection.vault);
    World.elsewhere.credentialsTake = const Duration(seconds: 10);
    await World.restartApp(tester);
    await World.vault.lookAt(World.backend, first.name);
    await World.settle(tester);
    expect(find.text('a-provider'), findsNothing);
    await tester.pump(const Duration(seconds: 11));
    await World.settle(tester);
    expect(find.text('second-entry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Harm: importing or forgetting a credential changes the title-bar machine instead of the leaf's.
  testWidgets('credential actions keep the machine named by their leaf', (tester) async {
    final first = await _start(tester);
    await _open(tester, MachineSection.credentials);
    World.machines.select(first);
    await World.settle(tester);
    final connections = tester.widget<ConnectionsView>(find.byType(ConnectionsView));
    connections.onForget('second.example.org');
    await World.settle(tester);
    expect(World.elsewhere.forgottenMatches, ['second.example.org']);
    expect(World.backend.forgottenMatches, isEmpty);
    await _open(tester, MachineSection.agents);
    World.machines.select(first);
    await World.settle(tester);
    final providers = tester.widget<AuthenticationView>(find.byType(AuthenticationView));
    providers.onImport('second-provider');
    await World.settle(tester);
    expect(World.elsewhere.imports, ['second-provider']);
    expect(World.backend.imports, isEmpty);
  });

  // Harm: confirming a stop on one machine stops another machine selected while the dialog waits.
  testWidgets('Managing keeps its emergency stop on the machine whose stop was previewed', (tester) async {
    final first = await _start(tester);
    await _open(tester, MachineSection.managing);
    await World.tapInView(tester, 'machine.panic');
    World.machines.select(first);
    await World.settle(tester);
    await World.tapInView(tester, 'stop-it-all');
    expect(World.elsewhere.panics, [true, false]);
    expect(World.backend.panics, isEmpty);
  });

  // Harm: a leaf can display another machine's data or send a command to its daemon.
  for (final section in MachineSection.values) {
    testWidgets('each section of a machine reads that machine: ${section.name}', (tester) async {
      final first = await _start(tester);
      await _open(tester, section);
      expect(World.shell.opened, isA<NothingOpened>(), reason: 'a machine section is a page, not an overlay');
      expect(find.byKey(ValueKey('machine-section-path ${_second.name}')), findsOneWidget);
      expect(World.shell.place.machine, _second);
      // A title-bar selection must not silently replace the owner named by the leaf.
      World.machines.select(first);
      await World.settle(tester);
      expect(World.shell.place.machine, _second);
      switch (section) {
        case MachineSection.tasks:
          expect(find.byKey(const Key('tile elsewhere porelo-shared-shell')), findsOneWidget);
          expect(find.byKey(ValueKey('tile ${first.name} porelo-checkout-shell')), findsNothing);
        case MachineSection.projects:
          expect(find.byKey(const Key('machine-projects elsewhere')), findsOneWidget);
          expect(find.byKey(const Key('project elsewhere/shared')), findsOneWidget);
          expect(find.byKey(ValueKey('project ${first.name}/checkout')), findsNothing);
        case MachineSection.vault:
          expect(find.text('second-entry'), findsOneWidget);
          expect(find.text('a-provider'), findsNothing);
        case MachineSection.credentials:
          final view = tester.widget<ConnectionsView>(find.byType(ConnectionsView));
          expect(view.connections.machine, _second.name);
          expect(find.text('second.example.org'), findsOneWidget);
          expect(tester.widget<DestinationsDialog>(find.byType(DestinationsDialog)).backend, World.elsewhere);
        case MachineSection.agents:
          expect(find.text('Second agent'), findsOneWidget);
          expect(find.text('Second provider'), findsOneWidget);
        case MachineSection.health:
          final view = tester.widget<HostReadinessView>(find.byType(HostReadinessView));
          expect(view.machine, _second.name);
          expect(find.text('Second machine'), findsOneWidget);
          expect(find.byKey(const Key('probe')), findsOneWidget, reason: 'each readiness check appears once');
          final before = World.backend.healthAsked;
          final ownBefore = World.elsewhere.healthAsked;
          await World.tapInView(tester, 'check-again');
          expect(World.backend.healthAsked, before, reason: 'checking the leaf cannot probe the current machine');
          expect(World.elsewhere.healthAsked, ownBefore + 1);
        case MachineSection.managing:
          expect(find.textContaining('elsewhere'), findsWidgets);
          final stop = tester.widget<ButtonStyleButton>(find.byKey(const Key('machine.stop')));
          expect(stop.onPressed, isNotNull, reason: 'the leaf must be able to stop its own host');
          await World.tapInView(tester, 'machine.stop');
          await World.tapInView(tester, 'stop-it');
          expect(World.stopsAsked, [Tunnels.stopCommandFor(_second)]);
          expect(World.backend.absent, isNull);
          expect(World.elsewhere.absent, isA<VarlinkDisconnected>());
          expect(World.machines.current, first);
      }
      expect(tester.takeException(), isNull);
    });
  }

  // Harm: a section drawn as a closable overlay invites a close that leads nowhere, and hides the page's head.
  for (final width in [1280.0, 390.0]) {
    testWidgets('no leaf draws a panel with a close button: $width', (tester) async {
      await _start(tester, organization: FixtureOrganization(organizationFor('olive')));
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await World.settle(tester);
      void expectNoPanel(String leaf) {
        expect(find.byType(PaneHeader), findsNothing, reason: leaf);
        expect(find.byType(PaneBody), findsNothing, reason: leaf);
        expect(find.byTooltip('Close (Esc)'), findsNothing, reason: leaf);
        // The filter's clear and the explanation's fold are no panel's close.
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is IconButton &&
                widget.icon is Icon &&
                (widget.icon as Icon).icon == Icons.close &&
                !{'Clear the filter', 'Close this explanation'}.contains(widget.tooltip),
          ),
          findsNothing,
          reason: leaf,
        );
      }

      for (final section in MachineSection.values) {
        World.shell.choosePlace(ShellPlace(Section.machine, machine: _second, machineSection: section));
        await World.settle(tester);
        expect(find.byKey(ValueKey('machine-section-path ${_second.name}')), findsOneWidget, reason: section.name);
        expectNoPanel(section.name);
      }
      for (final section in OrganizationSection.values) {
        await toTheOrganization(tester, section: section);
        await closeNavigationTree(tester);
        expectNoPanel(section.name);
      }
      expect(tester.takeException(), isNull);
    });
  }

  // Harm: a section's rows read differently from every other list, so a state is missed or a row's action not found.
  for (final width in [1280.0, 390.0]) {
    testWidgets("a machine's listing sections draw their rows in the shared list look: $width", (tester) async {
      await _start(tester);
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await World.settle(tester);
      // A row that folds open keeps its fold as a tile; its name, state chip and card are the list's.
      final rowLook = find.byWidgetPredicate(
        (widget) => widget is ItemListRow || widget is LeafListRow || widget is ExpansionTile,
      );
      final card = find.byWidgetPredicate(
        (widget) => widget is FilteredListSection && widget.leaf || widget is LeafRowsCard,
      );
      void expectRow(String name, {String? subtitle}) {
        final row = find.ancestor(of: find.text(name), matching: rowLook);
        expect(row, findsOneWidget, reason: name);
        expect(
          find.ancestor(of: row, matching: card),
          findsWidgets,
          reason: '$name sits in the white card',
        );
        expect(
          find.descendant(of: row, matching: find.byType(StateChip)),
          findsOneWidget,
          reason: name,
        );
        if (subtitle != null) expect(tester.widget<ItemListRow>(row).subtitle, subtitle);
      }

      for (final section in [
        MachineSection.vault,
        MachineSection.health,
        MachineSection.credentials,
        MachineSection.agents,
        MachineSection.managing,
      ]) {
        World.shell.choosePlace(ShellPlace(Section.machine, machine: _second, machineSection: section));
        await World.settle(tester);
        final head = find.byType(PageHead);
        expect(head, findsOneWidget, reason: section.name);
        // A phone names the page in its title bar instead of a large title.
        if (section == MachineSection.managing) {
          // Managing is titled by its machine; the path names the section.
          expect(tester.widget<PageHead>(head).title, _second.name);
        } else if (width >= 600) {
          expect(tester.widget<Text>(find.byKey(const Key('leaf-title'))).data, section.label);
        } else {
          expect(find.text(section.label), findsWidgets, reason: section.name);
        }
        expect(tester.widget<PageHead>(head).subtitle, isNotNull, reason: '${section.name} says what it holds');
        expect(
          find.descendant(of: head, matching: find.byKey(ValueKey('machine-section-path ${_second.name}'))),
          findsOneWidget,
        );
        switch (section) {
          case MachineSection.vault:
            expectRow('second-entry', subtitle: 'api-key · 24 characters');
            expect(tester.widget<PageHead>(head).subtitle, startsWith('Made · open · '));
          case MachineSection.health:
            expectRow('second-probe');
          case MachineSection.credentials:
            expectRow('second.example.org');
          case MachineSection.agents:
            expectRow('Second agent');
            expectRow('Second provider');
          case MachineSection.managing:
            // One page: its head and its facts and actions, never a second page's path and title under a head.
            expect(
              find.descendant(of: find.byKey(const Key('facts-page')), matching: find.byType(PageHead)),
              findsOneWidget,
            );
            expect(
              find.descendant(of: find.byKey(const Key('facts-page')), matching: find.text('My machines')),
              findsOneWidget,
              reason: 'the path is drawn once',
            );
            expect(find.byKey(const Key('machine.stop')), findsOneWidget);
          case MachineSection.tasks:
          case MachineSection.projects:
            break;
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  // Harm: a vault row shows or offers a stored secret.
  testWidgets("the vault's rows show a name and its kind and never a value", (tester) async {
    await _start(tester);
    World.shell.choosePlace(const ShellPlace(Section.machine, machine: _second, machineSection: MachineSection.vault));
    await World.settle(tester);
    final row = find.ancestor(of: find.text('second-entry'), matching: find.byType(ItemListRow));
    expect(row, findsOneWidget);
    final drawn = tester.widget<ItemListRow>(row);
    expect(drawn.title, 'second-entry');
    expect(drawn.subtitle, isNot(contains('never-render-this-value')));
    expect(find.textContaining('never-render-this-value', findRichText: true), findsNothing);
    expect(find.byType(EditableText), findsOneWidget, reason: 'only the filter takes text; no value is in a field');
  });

  // Harm: a managing page drawn as two heads and loose lines hides which machine it manages and why an action waits.
  for (final width in [1280.0, 390.0]) {
    testWidgets('Managing names its machine once, with its facts as tiles: $width', (tester) async {
      await _start(tester);
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      World.shell.choosePlace(
        const ShellPlace(Section.machine, machine: _second, machineSection: MachineSection.managing),
      );
      await World.settle(tester);
      final head = find.byType(PageHead);
      expect(head, findsOneWidget, reason: 'the head appears once');
      final drawn = tester.widget<PageHead>(head);
      expect(drawn.title, _second.name);
      expect(drawn.subtitle, contains('Porelo '));
      final path = find.descendant(of: head, matching: find.byKey(ValueKey('machine-section-path ${_second.name}')));
      expect(find.descendant(of: path, matching: find.text('Managing this machine')), findsOneWidget);
      expect(
        find.descendant(of: head, matching: find.byType(StateChip)),
        findsOneWidget,
        reason: 'its state',
      );
      expect(find.byType(VaultButtons), findsNothing, reason: 'no lone lock icon');
      expect(find.byIcon(Icons.pending_outlined), findsNothing);
      for (final tile in ['connection', 'vault', 'work', 'health']) {
        final found = find.byKey(ValueKey('managing-tile $tile'));
        expect(found, findsOneWidget, reason: tile);
        for (final part in ['label', 'value', 'detail']) {
          expect(
            find.descendant(of: found, matching: find.byKey(Key('tile-$part'))),
            findsOneWidget,
            reason: '$tile $part',
          );
        }
      }
      String tileText(String tile, String part) => tester
          .widget<Text>(
            find.descendant(of: find.byKey(ValueKey('managing-tile $tile')), matching: find.byKey(Key('tile-$part'))),
          )
          .data!;
      expect(tileText('vault', 'value'), 'Open');
      expect(tileText('vault', 'detail'), startsWith('1 entr'));
      expect(tileText('connection', 'value'), 'Connected');
      expect(tileText('connection', 'detail'), _second.where);
      expect(find.byKey(const Key('vault.make')), findsNothing, reason: 'a vault that exists is not made again');
      final danger = find.byKey(const Key('danger-zone'));
      expect(danger, findsOneWidget);
      final dangerous = find
          .descendant(of: danger, matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton))
          .evaluate()
          .map((element) => (element.widget.key! as ValueKey<String>).value)
          .toSet();
      expect(dangerous, {'machine.panic', 'machine.clear'});
      expect(find.textContaining('Last read: '), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  // Harm: a greyed action's reason stands apart from it, so a person cannot tell which action waits and why.
  testWidgets("Managing says a waiting action's reason beside its button", (tester) async {
    final backend = _GuardedBackend()..absent = const VarlinkDisconnected('No daemon');
    await _start(tester, secondBackend: backend);
    World.shell.choosePlace(
      const ShellPlace(Section.machine, machine: _second, machineSection: MachineSection.managing),
    );
    await World.settle(tester);
    final actions = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('managing-action '),
    );
    expect(actions, findsWidgets);
    var waiting = 0;
    for (final action in actions.evaluate().toList()) {
      final button = find.descendant(
        of: find.byWidget(action.widget),
        matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
      );
      if (tester.widget<ButtonStyleButton>(button.first).onPressed != null) continue;
      waiting++;
      expect(
        find.descendant(of: find.byWidget(action.widget), matching: find.textContaining('Not now: ')),
        findsOneWidget,
        reason: '${action.widget.key}',
      );
    }
    expect(waiting, greaterThan(0), reason: 'a machine that does not answer has actions that wait');
    final loose = find.textContaining('This machine has not answered about its vault.');
    for (final line in loose.evaluate()) {
      expect(find.ancestor(of: find.byWidget(line.widget), matching: actions), findsWidgets);
    }
  });

  // Harm: secret values can leak through a vault page or a misplaced machine's vault.
  testWidgets('the vault leaf shows names and kinds and no value', (tester) async {
    final first = await _start(tester);
    await _open(tester, MachineSection.vault);
    World.machines.select(first);
    await World.settle(tester);
    expect(World.shell.opened, isA<NothingOpened>());
    expect(find.byType(VaultView), findsOneWidget);
    expect(find.text('second-entry'), findsOneWidget);
    expect(find.textContaining('api-key'), findsWidgets);
    expect(find.textContaining('never-render-this-value'), findsNothing);
    expect(find.text('a-provider'), findsNothing);
  });
}

class _WaitingRefreshBackend extends FakeBackend {
  _WaitingRefreshBackend() : super([World.aTask('porelo-shared-shell', 'shared')]);

  Completer<List<Project>>? waitForProjects;
  bool refreshWaiting = false;

  @override
  Future<List<Project>> projects() {
    final waiting = waitForProjects;
    if (waiting == null) return super.projects();
    refreshWaiting = true;
    return waiting.future;
  }
}

class _GuardedBackend extends FakeBackend {
  _GuardedBackend() : super([]);

  bool _opened = false;
  int toolReads = 0;
  int destinationReads = 0;

  @override
  Future<ServiceInfo> open() async {
    final info = await super.open();
    _opened = true;
    return info;
  }

  void _guard() {
    toolReads++;
    if (!_opened) throw StateError('open() has not answered yet');
  }

  @override
  Future<VaultState> credentials() {
    _guard();
    return super.credentials();
  }

  @override
  Future<AgentsOnTheMachine> agentsOn() {
    _guard();
    return super.agentsOn();
  }

  @override
  Future<Providers> providers() {
    _guard();
    return super.providers();
  }

  @override
  Future<Health> doctor() {
    _guard();
    return super.doctor();
  }

  @override
  Future<List<Destination>> destinations() {
    _guard();
    destinationReads++;
    return super.destinations();
  }
}
