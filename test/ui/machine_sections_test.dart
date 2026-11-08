import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/authentication_view.dart';
import 'package:porelo_frontend/src/ui/connections_view.dart';
import 'package:porelo_frontend/src/ui/destinations_view.dart';
import 'package:porelo_frontend/src/ui/host_readiness_view.dart';
import 'package:porelo_frontend/src/ui/vault_view.dart';

import '../features/support/tiles.dart';
import '../features/support/world.dart';

const _second = Machine(name: 'elsewhere', socketPath: '/unused');

Future<Machine> _start(WidgetTester tester, {FakeBackend? secondBackend}) async {
  await World.startBackend(World.work);
  await World.startApp(tester);
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
          final stop = tester.widget<FilledButton>(find.byKey(const Key('machine.stop')));
          expect(stop.onPressed, isNull, reason: 'a current-selection command cannot stop a different machine');
      }
      expect(tester.takeException(), isNull);
    });
  }

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
