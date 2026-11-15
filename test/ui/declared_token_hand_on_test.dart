import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/host_progress.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_host/porelo_host.dart' as host;

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';

/// The organization's repository, which the declared entry below matches.
const _repository = 'https://forge.example.org/acme/organization.git';

/// The window as hana, Machine Admin of `build`, which says it waits for her token for `demo`; this computer's
/// Porelo-Vault declares a token for the organization's forge where [declared].
Future<(FixtureOrganization, FixtureConnections)> _waiting(WidgetTester tester, {required bool declared}) async {
  await World.startBackend(World.work);
  final source = FixtureOrganization(organizationFor('hana', address: _repository));
  final connections = FixtureConnections(['build'])
    ..hostProgress = HostProgress.read('{"projects":[{"project":"demo","state":"waiting-for-token"}]}');
  await World.startApp(tester, organizationSource: source, hostConnections: connections);
  // Before the host is heard: what this computer's Porelo-Vault declares.
  World.here.theConnections = [
    if (declared)
      const Connection(
        id: 'acme-token',
        kind: 'TOKEN',
        match: 'https://forge.example.org/acme',
        purpose: 'git',
        present: true,
      ),
  ];
  final card = host.HostCardSsh(
    name: 'build',
    address: buildHost.address!,
    sshPort: buildHost.port!,
    hostKey: buildHost.hostKey!,
    login: 'hana',
    publicKey: buildHost.hostKey!,
    webPort: buildHost.webPort,
  );
  await World.machines.add(Machine.fromHostCard(card, socketPath: '/unused'));
  await World.settle(tester);
  return (source, connections);
}

void main() {
  // Harm: a Machine Admin whose Porelo-Vault declares the token is asked for it again for each project on the host,
  // or a token that did not help is handed on in a loop.
  testWidgets('a host heard waiting for the token is handed the declared one by itself, once per wait', (tester) async {
    final (source, connections) = await _waiting(tester, declared: true);

    expect(source.handedTo, ['build'], reason: 'handed on without a press');
    expect(find.byKey(const Key('organization.tokenPage')), findsNothing, reason: 'nothing opens');

    // The host still says it waits: the same wait is not answered again by itself.
    connections.notifyListeners();
    await World.settle(tester);
    expect(source.handedTo, ['build']);
  });

  // Harm: where nothing is declared, a page opens by itself, or something is handed on all the same.
  testWidgets('where nothing is declared, nothing is handed on and nothing opens', (tester) async {
    final (source, _) = await _waiting(tester, declared: false);

    expect(source.handedTo, isEmpty);
    expect(find.byKey(const Key('organization.tokenPage')), findsNothing);
  });
}
