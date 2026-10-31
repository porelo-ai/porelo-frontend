import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/join_adapters.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/project_join.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/registry_checkout.dart';
import 'package:porelo_frontend/src/app/registry_pages.dart';
import 'package:porelo_frontend/src/app/registry_read_source.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/projects_page.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart' show FakeBackend, World;
import '../support/host_admin.dart';
import '../support/project_join.dart';
import '../support/signed_host.dart';

void main() {
  // Harm: a person with nothing followed and no host watched has no way in but typing and pasting.
  testWidgets('an admission says where it is and joins at one click, asking for nothing', (tester) async {
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    addTearDown(machines.dispose);
    addTearDown(settings.dispose);
    final offer = JoinOffered(
      project: 'demo',
      host: PreparedHost.read(hostValues()),
      login: 'porelo-alice',
      source: 'https://forge.example/team/demo.git',
      revision: 'a' * 40,
      signers: [personKey],
    );
    final core = FakeDiscovery()..answer = [offer];
    final host = FakeJoinHost();
    final join = ProjectJoin(offer: offer, discovery: core, host: host, machines: machines, settings: settings);
    addTearDown(join.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: joinRow(offer, join))));
    expect(find.textContaining('in project demo on host ${offer.host.name}'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(ValueKey('join ${offer.key}')));
    await tester.pumpAndSettle();
    expect(join.joined, isTrue);
    expect(find.textContaining('Joined'), findsOneWidget);
    expect(find.byKey(ValueKey('join ${offer.key}')), findsNothing);
  });

  // Harm: Core verified where the person may join, and the window shows them no way in, or a Join that does nothing;
  // one refused commit in the registry closes every host, and a host whose access file was refused is never shown.
  testWidgets('the shell shows the rows Core\'s discovery answers through the registry pages\' read, and Join joins', (
    tester,
  ) async {
    final world = _Registry()..refused = {'commit': 'c' * 40, 'path': 'hosts/grove/access.yml', 'why': 'unsigned'};
    final host = FakeJoinHost();
    await world.start(tester, host);
    expect(find.textContaining('in project demo on host orchard'), findsOneWidget);
    expect(find.textContaining('The registry refused the access file of grove'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('join demo@orchard')));
    await World.settle(tester);
    expect(host.calls, ['connect orchard', 'follow demo https://forge.example/team/demo.git $personKey']);
    expect(World.settings.projectHost('demo'), 'orchard');
    expect(find.textContaining('Joined'), findsOneWidget);
  });

  // Harm: a person who chose no registry is never told why no project to join is shown.
  testWidgets('with no registry chosen the shell says so', (tester) async {
    final world = _Registry()..address = null;
    await world.start(tester, FakeJoinHost());
    expect(world.joinable, 0);
    expect(World.machines.fleet.status, CoreJoinDiscovery.noRegistry, reason: 'the status line says it');
  });

  // Harm: rows of a registry whose read now fails stay offered, joined from a state not read here.
  testWidgets('a registry read that fails takes every row away', (tester) async {
    final world = _Registry();
    await world.start(tester, FakeJoinHost());
    expect(find.textContaining('in project demo on host orchard'), findsOneWidget);
    world.fetchFails = true;
    await tester.tap(find.byKey(const Key('refresh-all')));
    await World.settle(tester);
    World.shell.goTo(Section.projects);
    await World.settle(tester);
    expect(find.textContaining('in project demo on host orchard'), findsNothing);
  });

  // Harm: a row Core answers anew after a refresh keeps its old join, which refuses for good.
  testWidgets('a row Core answers anew joins what Core answers now', (tester) async {
    final world = _Registry();
    final host = FakeJoinHost();
    await world.start(tester, host);
    world.revision = 'd' * 40;
    await tester.tap(find.byKey(const Key('refresh-all')));
    await World.settle(tester);
    World.shell.goTo(Section.projects);
    await World.settle(tester);
    await tester.tap(find.byKey(const ValueKey('join demo@orchard')));
    await World.settle(tester);
    expect(find.textContaining('no longer verifies'), findsNothing);
    expect(World.settings.projectHost('demo'), 'orchard');
  });

  // Harm: discovery reads the registry checkout while its first fetch and read still run, and offers rows from a
  // registry not read here.
  testWidgets('discovery waits for the registry pages\' read', (tester) async {
    final source = _HeldSource();
    final discovery = _CountingDiscovery();
    await World.startBackend(World.work);
    await World.startApp(
      tester,
      registryPages: RegistryPages(source: source, address: () => 'https://forge.example/team/registry.git'),
      joinDiscovery: discovery,
      joinHost: FakeJoinHost(),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(discovery.asked, 0, reason: 'the registry read still runs');
    source.reading.complete();
    await World.settle(tester);
    expect(discovery.asked, 1);
  });

  // Harm: an access file that cannot be read looks like a person with no projects.
  testWidgets('an unreadable access repository is a row of its own naming who may grant it', (tester) async {
    const unreadable = JoinUnreadable(
      host: 'orchard',
      repository: 'https://forge.example/team/access.git',
      whoMay: [RegistryContact(login: 'bob', name: 'Bob', email: 'bob@example.org')],
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Builder(builder: _unreadable)),
      ),
    );
    expect(find.text(unreadable.repository!), findsOneWidget);
    expect(find.textContaining('Bob (bob)'), findsOneWidget);
  });
}

Widget _unreadable(BuildContext context) => joinRow(
  const JoinUnreadable(
    host: 'orchard',
    repository: 'https://forge.example/team/access.git',
    whoMay: [RegistryContact(login: 'bob', name: 'Bob', email: 'bob@example.org')],
  ),
  null,
);

/// A registry read that ends when the test says.
class _HeldSource implements RegistryPageSource {
  Completer<void> reading = Completer<void>();

  @override
  Future<RegistryPageSnapshot> read() async {
    await reading.future;
    return const RegistryPageSnapshot();
  }

  @override
  Future<String> publish(RegistryPageChange change) => throw UnimplementedError();

  @override
  Future<RegistryHostState> apply(RegistryTarget target, String revision) => throw UnimplementedError();
}

/// Core's discovery, counting each ask.
class _CountingDiscovery implements JoinDiscovery {
  int asked = 0;

  @override
  Future<List<JoinAdmission>> admissions() async {
    asked++;
    return const [];
  }
}

const _registryAddress = 'https://forge.example/team/registry.git';

/// The app's registry, read by Core's fakes, and the join discovery the app makes on it, as the window is given them.
class _Registry implements RegistryCheckout, RegistryCore {
  /// The registry chosen, or null before one was.
  String? address = _registryAddress;

  /// The commit Core refused beside the accepted revision, or null.
  Map<String, dynamic>? refused;

  /// Whether the next fetch fails.
  bool fetchFails = false;

  /// The access commit Core verified for the project.
  String revision = 'a' * 40;

  /// How often `registry joinable` was asked.
  int joinable = 0;

  Future<void> start(WidgetTester tester, JoinHost host) async {
    final source = RegistryReadSource(
      repository: () => address,
      open: (_) => Registry(checkout: this, core: this),
      machines: () => const [],
    );
    final settings = Settings(MemorySettingsStore());
    final spare = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    addTearDown(spare.dispose);
    addTearDown(settings.dispose);
    final joins = appJoins(registry: source, machines: spare, run: _run);
    await World.startBackend(World.work);
    await World.startApp(
      tester,
      registryPages: RegistryPages(
        source: source,
        features: const RegistryPageFeatures(operations: {RegistryOperation.refresh}),
        address: () => address,
      ),
      joinDiscovery: joins.discovery,
      joinHost: host,
    );
    World.shell.goTo(Section.projects);
    await World.settle(tester);
  }

  Future<Ran> _run(
    String program,
    List<String> arguments, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) async {
    if (arguments.first == 'identity') return (code: 0, out: jsonEncode(_shown), err: '');
    joinable++;
    return (
      code: 0,
      out: jsonEncode({
        'projects': [
          {
            'project': 'demo',
            'host': 'orchard',
            'host_account': 'alice',
            'host_card': {'host': 'orchard', ...hostValues()..remove('name'), 'signed_by': 'SHA256:${'A' * 43}'},
            'homeserver': null,
            'source': 'https://forge.example/team/demo.git',
            'access_repository': 'https://forge.example/team/access.git',
            'revision': revision,
            'signers': [personKey],
            'admins': [
              {'login': 'bob', 'name': null, 'email': null},
            ],
          },
        ],
        'refused': [
          if (refused != null)
            {
              'project': null,
              'host': 'grove',
              'access_repository': null,
              'why': 'hosts/grove/access.yml in cccccccc: unsigned',
              'admins': [
                {'login': 'dave', 'name': null, 'email': null},
              ],
            },
        ],
      }),
      err: '',
    );
  }

  Map<String, Object?> get _shown => {
    'login': 'alice',
    'name': 'Alice',
    'email': null,
    'fingerprint': pinnedAs(personKey),
    'key': personKey,
    'created': '2026-10-31',
    'expires': '2026-11-30',
    'predecessor': null,
    'card': 'login: "alice"\n',
    'agent': 'holds',
    'agent_holds_key': true,
    'revoked': false,
    'card_refused': null,
    'registry': [
      {
        'address': _registryAddress,
        'filed': 'done',
        'revision': 'b' * 40,
        'may_file': true,
        'who_may': [
          {'login': 'carol', 'name': null, 'email': null},
        ],
      },
    ],
    'forge': null,
    'pending': <Object?>[],
  };

  @override
  String get repository => address ?? _registryAddress;

  @override
  String get root => '/private/registry';

  @override
  String get folder => '/private/registry/registry';

  @override
  Future<String> fetch() async =>
      fetchFails ? throw const WorkspaceRefused('The registry could not be fetched.') : 'b' * 40;

  @override
  Future<void> prepareRetry({required String base, required String file, required String content}) =>
      throw UnimplementedError();

  @override
  Future<void> prepareFiling() async {}

  @override
  Future<void> publishMade(String revision, {required String base}) async {}

  @override
  Future<void> publish(String revision) async {}

  @override
  Future<RegistryRead> read(String checkout) async => RegistryRead.from({
    'revision': 'b' * 40,
    'people': <Object?>[],
    'owners': <Object?>[],
    'warnings': <Object?>[],
    'hosts': <Object?>[],
    'refused_commit': ?refused,
  });

  @override
  Future<RegistryFiled> file(String checkout, RegistryFiling filing) => throw UnimplementedError();
}
