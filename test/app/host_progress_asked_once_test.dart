import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_progress.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';

import '../support/organization_fixtures.dart';

void main() {
  // Harm: a machine is asked how far it has come, which logs in as root, for a person who is not its Machine Admin, and
  // each refused login counts against them; or asked again on every change, a fan of root logins.
  test('a machine is asked how far it has come once, and only for its connected Machine Admin', () async {
    final connections = FixtureConnections(['build', 'spare'])
      ..hostProgress = HostProgress.read('{"projects":[{"project":"demo","state":"waiting-for-token"}]}');
    addTearDown(connections.dispose);

    // mia is a member of demo on build, and administers no machine.
    connections.askOnce(organizationFor('mia'));
    await pumpEventQueue();
    expect(connections.asked, isEmpty);
    expect(connections.heard('build'), isNull);

    // hana administers build alone; spare is olive's.
    final hana = organizationFor('hana');
    connections
      ..askOnce(hana)
      ..askOnce(hana);
    await pumpEventQueue();
    connections.askOnce(hana);
    await pumpEventQueue();
    expect(connections.asked, ['progress build']);
    expect(connections.heard('build')?.of('demo')?.waitsForToken, isTrue);

    // Asked again once the connection went and came back, not before.
    connections.hosts.remove('build');
    connections.askOnce(hana);
    connections.hosts.add('build');
    connections.askOnce(hana);
    await pumpEventQueue();
    expect(connections.asked, ['progress build', 'progress build']);
  });

  // Harm: a machine answering after the window let its connections go throws, and the answer's caller fails with it.
  test('an answer that comes after the connections were let go is dropped quietly', () async {
    final connections = FixtureConnections(['build']);
    final asked = connections.progress('build');
    connections.dispose();
    await expectLater(asked, completes);
  });

  // Harm: what a machine said to its Machine Admin goes on standing after the connection went or the role was taken,
  // and a page offers the token for a state nobody read since.
  test('what a machine said is forgotten once it may no longer be asked', () async {
    final connections = FixtureConnections(['build'])
      ..hostProgress = HostProgress.read('{"projects":[{"project":"demo","state":"waiting-for-token"}]}');
    addTearDown(connections.dispose);
    connections.askOnce(organizationFor('hana'));
    await pumpEventQueue();
    expect(connections.heard('build'), isNotNull);
    // hana is no longer its Machine Admin.
    connections.askOnce(
      organizationFor(
        'hana',
        host: const OrganizationHost(name: 'build', admins: ['pat']),
      ),
    );
    expect(connections.heard('build'), isNull);
    connections.askOnce(organizationFor('hana'));
    await pumpEventQueue();
    expect(connections.heard('build'), isNotNull);
    connections.hosts.remove('build');
    connections.askOnce(organizationFor('hana'));
    connections.hosts.add('build');
    expect(connections.heard('build'), isNull, reason: 'not since it came back');
  });

  // Harm: an answer asked before the role was taken or the connection went lands after it, and stands again.
  test('an answer on its way when the machine may no longer be asked is not kept', () async {
    final connections = FixtureConnections(['build'])
      ..hostProgress = HostProgress.read('{"projects":[{"project":"demo","state":"waiting-for-token"}]}');
    addTearDown(connections.dispose);
    connections.askOnce(organizationFor('hana'));
    connections.askOnce(
      organizationFor(
        'hana',
        host: const OrganizationHost(name: 'build', admins: ['pat']),
      ),
    );
    await pumpEventQueue();
    expect(connections.heard('build'), isNull);
  });
}
