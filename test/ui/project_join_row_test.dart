import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/project_join.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/projects_page.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart' show FakeBackend;
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
    expect(find.text(unreadable.repository), findsOneWidget);
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
