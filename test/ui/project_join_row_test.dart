import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/project_join.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/registry_pages.dart';
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

  // Harm: Core verified where the person may join, and the window shows them no way in, or a Join that does nothing.
  testWidgets('the shell shows the row Core\'s discovery answers, and its Join joins', (tester) async {
    final offer = JoinOffered(
      project: 'demo',
      host: PreparedHost.read(hostValues()),
      login: 'porelo-alice',
      source: 'https://forge.example/team/demo.git',
      revision: 'a' * 40,
      signers: [personKey],
    );
    final host = FakeJoinHost();
    await World.startBackend(World.work);
    await World.startApp(tester, joinDiscovery: FakeDiscovery()..answer = [offer], joinHost: host);
    World.shell.goTo(Section.projects);
    await World.settle(tester);
    expect(find.textContaining('in project demo on host ${offer.host.name}'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('join ${offer.key}')));
    await World.settle(tester);
    expect(host.calls, ['connect ${offer.host.name}', 'follow demo ${offer.source} $personKey']);
    expect(World.settings.projectHost('demo'), offer.host.name);
    expect(find.textContaining('Joined'), findsOneWidget);
  });

  // Harm: discovery reads the registry checkout while its first fetch and read still run, or after that read was
  // refused, and offers rows from a registry not read here.
  for (final refused in [false, true]) {
    testWidgets(
      'discovery waits for the registry pages\' read${refused ? ', and asks nothing after a refused one' : ''}',
      (tester) async {
        final source = _HeldSource()..refuses = refused;
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
        expect(discovery.asked, refused ? 0 : 1);
      },
    );
  }

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

/// A registry read that ends when the test says, refusing when it says.
class _HeldSource implements RegistryPageSource {
  Completer<void> reading = Completer<void>();
  bool refuses = false;

  @override
  Future<RegistryPageSnapshot> read() async {
    await reading.future;
    if (refuses) throw const RegistryRefusal('Porelo refused the newest registry commit.');
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
