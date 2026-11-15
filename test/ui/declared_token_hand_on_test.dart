import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/declared_hand_on.dart';
import 'package:porelo_frontend/src/app/host_progress.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/porelo_organization_source.dart';
import 'package:porelo_host/porelo_host.dart' as host;

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';

/// What `build` says while `demo` waits for the token.
final _demoWaits = HostProgress.read('{"projects":[{"project":"demo","state":"waiting-for-token"}]}');

/// What `build` says once `demo` took the token and is carried.
final _demoCarried = HostProgress.read('{"projects":[{"project":"demo","state":"carried"}]}');

/// What `build` says while it clones `demo`, the token handed on, before it says how that went.
final _demoCloning = HostProgress.read('{"projects":[{"project":"demo","state":"cloning"}]}');

/// The organization's repository, which the declared entry below matches.
const _repository = 'https://forge.example.org/acme/organization.git';

/// The window as hana, Machine Admin of `build`, which says it waits for her token for `demo`; this computer's
/// Porelo-Vault declares a token for the organization's forge where [declared].
///
/// [prepare] is given both before the host is added, as a test makes Porelo answer otherwise.
Future<(FixtureOrganization, FixtureConnections)> _waiting(
  WidgetTester tester, {
  required bool declared,
  void Function(FixtureOrganization source, FixtureConnections connections)? prepare,
}) async {
  await World.startBackend(World.work);
  final source = FixtureOrganization(organizationFor('hana', address: _repository));
  final connections = FixtureConnections(['build'])..hostProgress = _demoWaits;
  prepare?.call(source, connections);
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

  // Harm: a project that waits for the token again, after the host took it, is never handed it by itself again.
  testWidgets('a project heard waiting again after it stopped waiting is a new wait', (tester) async {
    final (source, connections) = await _waiting(tester, declared: true);
    expect(source.handedTo, ['build']);

    connections.hostProgress = _demoCarried;
    await connections.progress('build');
    await World.settle(tester);
    // Say, a repository was added to demo: it waits for the token once more.
    connections.hostProgress = _demoWaits;
    await connections.progress('build');
    await World.settle(tester);

    expect(source.handedTo, ['build', 'build'], reason: 'the new wait is handed on, once');
    connections.notifyListeners();
    await World.settle(tester);
    expect(source.handedTo, ['build', 'build']);
  });

  // Harm: a token that does not help is handed on in a loop, as the host passes through another state between waits.
  testWidgets('a project passing through another state and waiting again is the same wait', (tester) async {
    final (source, connections) = await _waiting(tester, declared: true);
    expect(source.handedTo, ['build']);

    connections.hostProgress = _demoCloning;
    await connections.progress('build');
    await World.settle(tester);
    connections.hostProgress = _demoWaits;
    await connections.progress('build');
    await World.settle(tester);

    expect(source.handedTo, ['build'], reason: 'not taken in between: the token that did not help is not given again');
  });

  // Harm: a hand-over that could not run, the host not reached, counts as answered, so the wait is never handed on;
  // or it is tried again on every word while the host stays out of reach.
  testWidgets('a hand-over that could not reach the host is tried again a minute later', (tester) async {
    var now = DateTime.utc(2026, 11, 15, 18);
    declaredHandOnClock = () => now;
    addTearDown(() => declaredHandOnClock = DateTime.now);
    final (source, connections) = await _waiting(
      tester,
      declared: true,
      prepare: (_, connections) =>
          connections.refuseNextConnect = const OrganizationRefused('build is not reached now.'),
    );
    expect(connections.asked.where((asked) => asked == 'connect build'), hasLength(1));
    expect(source.handedTo, isEmpty, reason: 'the host was not reached, and the words after it within the minute wait');

    now = now.add(const Duration(minutes: 1));
    connections.notifyListeners();
    await World.settle(tester);
    expect(source.handedTo, ['build'], reason: 'the same wait, not answered yet, is handed on once tried again');

    connections.notifyListeners();
    await World.settle(tester);
    expect(source.handedTo, ['build'], reason: 'answered now');
  });

  // Harm: Porelo's exit code for a host that waits for no token is taken for a refusal, said as a problem, or the
  // project is handed on in a loop.
  testWidgets("a host that waits for no token, by Porelo's exit code, is nothing to do", (tester) async {
    // Porelo's own source, run as Porelo answers where no project of the host waits.
    final porelo = PoreloOrganizationSource(
      run: (program, arguments, {inDirectory, environment = const {}, input}) async =>
          (code: 65, out: jsonEncode({'reason': 'refused-state', 'words': 'no project waits for a token'}), err: ''),
    );
    final (source, connections) = await _waiting(
      tester,
      declared: true,
      prepare: (source, _) => source.handOver = porelo.handTokenTo,
    );
    expect(source.handedTo, ['build']);

    final again = await connections.handOnDeclared!('build', {'demo'});
    expect(again.outcome, HandOnOutcome.nothingWaits, reason: 'what the hand-over came to');
    expect(source.handedTo, ['build'], reason: 'not handed on again for the same wait');
  });
}
