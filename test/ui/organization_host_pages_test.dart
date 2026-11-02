import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_progress.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/ui/organization_host_pages.dart';

import '../support/organization_fixtures.dart';

Finder _action(String id) => find.byKey(ValueKey('organization.$id'));
Finder _confirm() => find.byKey(const Key('organization-confirm'));

Future<void> _settle(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  group('the hosts under Machines', () {
    Future<({FixtureConnections connections, List<String> opened})> section(
      WidgetTester tester,
      OrganizationView view, {
      FixtureConnections? connections,
    }) async {
      final organization = Organization(FixtureOrganization(view));
      addTearDown(organization.dispose);
      final made = connections ?? FixtureConnections();
      final opened = <String>[];
      await _settle(
        tester,
        OrganizationHostsSection(organization: organization, connections: made, onHost: opened.add),
      );
      return (connections: made, opened: opened);
    }

    // Harm: a person with two projects on one host connects twice, and holds two connections to one account.
    testWidgets('two projects of a person on one host are one row and one connection', (tester) async {
      final made = await section(
        tester,
        organizationFor(
          'mia',
          moreProjects: const [
            OrganizationProject(name: 'third', admins: ['pat'], members: ['mia'], host: 'build'),
          ],
        ),
      );
      expect(find.byKey(const ValueKey('my-host build')), findsOneWidget);
      expect(_action('connect/build'), findsOneWidget);
      expect(find.textContaining('your projects: demo, third'), findsOneWidget);
      await _tap(tester, _action('connect/build'));
      expect(made.connections.asked, ['connect build']);
      expect(find.textContaining('connected, ready to work on'), findsOneWidget);
      expect(_action('connect/build'), findsNothing);
    });

    // Harm: a person is offered a host they have nothing to do on.
    testWidgets('a host carrying none of the person\'s projects is not offered', (tester) async {
      await section(tester, organizationFor('mia'));
      expect(find.byKey(const ValueKey('my-host spare')), findsNothing);
    });

    // Harm: a person whose card is not trusted is offered a connection the host refuses.
    testWidgets('a person holding no roles is offered no host', (tester) async {
      await section(tester, organizationFor('rex'));
      expect(find.byKey(const ValueKey('my-host build')), findsNothing);
    });

    // Harm: Connect fails with no way to tell why, or no address is mistaken for a broken network.
    testWidgets('a host with no address says so and cannot be connected to', (tester) async {
      await section(tester, organizationFor('olive'));
      expect(find.textContaining('Its host admin has not entered its address yet.'), findsOneWidget);
      expect(tester.widget<FilledButton>(_action('connect/spare')).onPressed, isNull);
    });

    // Harm: a person is left thinking they are connected, with no idea what to do next.
    testWidgets('a refused Connect shows its words and stays not connected', (tester) async {
      final connections = FixtureConnections()..refuseNext = const OrganizationRefused('The vault is locked.');
      await section(tester, organizationFor('mia'), connections: connections);
      await _tap(tester, _action('connect/build'));
      expect(find.text('The vault is locked.'), findsOneWidget);
      expect(_action('connect/build'), findsOneWidget);
      expect(find.textContaining('not connected yet'), findsOneWidget);
    });

    // Harm: a host's page cannot be reached.
    testWidgets('a row opens the host\'s page', (tester) async {
      final made = await section(tester, organizationFor('mia'));
      await _tap(tester, find.byKey(const ValueKey('my-host build')));
      expect(made.opened, ['build']);
    });
  });

  group('a host\'s page', () {
    Future<({FixtureOrganization source, FixtureConnections connections})> page(
      WidgetTester tester,
      String me, {
      FixtureConnections? connections,
      String host = 'build',
      List<OrganizationProject> moreProjects = const [],
      Future<void> Function(String host)? onGiveToken,
    }) async {
      final source = FixtureOrganization(organizationFor(me, moreProjects: moreProjects));
      final organization = Organization(source);
      addTearDown(organization.dispose);
      await organization.refresh();
      final made = connections ?? FixtureConnections();
      await _settle(
        tester,
        OrganizationHostPage(
          organization: organization,
          connections: made,
          host: host,
          onBack: () {},
          onGiveToken: onGiveToken,
        ),
      );
      return (source: source, connections: made);
    }

    // Harm: a person who may not manage a host is offered what the store refuses.
    testWidgets('a member sees the host and their connection, and no management', (tester) async {
      await page(tester, 'mia');
      expect(find.textContaining('203.0.113.7:22'), findsOneWidget);
      expect(find.text('demo'), findsOneWidget);
      expect(find.text('hana'), findsOneWidget);
      for (final id in [
        'changeHost',
        'refreshHost',
        'addProjectToHost',
        'removeProjectFromHost/demo',
        'addHostAdmin',
        'removeHostAdmin/hana',
      ]) {
        expect(_action(id), findsNothing, reason: id);
      }
      expect(_action('connect/build'), findsOneWidget);
    });

    // Harm: a project lands on two hosts at once, against the rule of one host at a time.
    testWidgets('putting a project on offers only those on no host, and writes the host and the project', (
      tester,
    ) async {
      final made = await page(tester, 'hana');
      await _tap(tester, _action('addProjectToHost'));
      await _tap(tester, find.byKey(const Key('organization-person')));
      expect(find.text('other').hitTestable(), findsOneWidget);
      expect(find.text('demo').hitTestable(), findsNothing);
      await _tap(tester, find.text('other').hitTestable());
      await _tap(tester, _confirm());
      final write = made.source.writes.single;
      expect(write.change, OrganizationChange.addProjectToHost);
      expect(write.input, {'host': 'build', 'project': 'other'});
    });

    // Harm: a host admin deletes a room's conversation with no word of it.
    testWidgets('taking a project off says what stays until its unpushed work is gone, and what goes then', (
      tester,
    ) async {
      final made = await page(tester, 'hana');
      await _tap(tester, _action('removeProjectFromHost/demo'));
      expect(find.textContaining('once it holds no unpushed work'), findsOneWidget);
      expect(find.textContaining('with its conversation'), findsOneWidget);
      expect(find.textContaining('up to five minutes'), findsOneWidget);
      await _tap(tester, _confirm());
      final write = made.source.writes.single;
      expect(write.change, OrganizationChange.removeProjectFromHost);
      expect(write.input, {'host': 'build', 'project': 'demo'});
    });

    // Harm: a host loses its last admin, or a refusal is lost.
    testWidgets('removing a host admin says the last cannot go, and shows the refusal', (tester) async {
      final made = await page(tester, 'hana');
      made.source.refuseNext = const OrganizationRefused('The last host admin cannot be removed.');
      await _tap(tester, _action('removeHostAdmin/hana'));
      expect(find.textContaining('The last host admin cannot be removed.'), findsOneWidget);
      await _tap(tester, _confirm());
      expect(find.textContaining('The last host admin cannot be removed.'), findsWidgets);
      expect(made.source.writes, hasLength(1));
    });

    // Harm: a person is named a host admin who cannot act, or who already is one.
    testWidgets('adding a host admin offers people holding roles who are not yet one', (tester) async {
      final made = await page(tester, 'hana');
      await _tap(tester, _action('addHostAdmin'));
      await _tap(tester, find.byKey(const Key('organization-person')));
      expect(find.text('pat').hitTestable(), findsOneWidget);
      expect(find.text('rex').hitTestable(), findsNothing);
      expect(
        find.text('nora').hitTestable(),
        findsOneWidget,
        reason: 'accepted, and the identity source cannot say yet',
      );
      await _tap(tester, find.text('pat').hitTestable());
      await _tap(tester, _confirm());
      expect(made.source.writes.single.input, {'host': 'build', 'login': 'pat'});
    });

    // Harm: a loopback address or an invalid key is signed into the organization, and everyone is pinned to it.
    testWidgets('changing address and host key checks them and writes all of them', (tester) async {
      final made = await page(tester, 'hana');
      await _tap(tester, _action('changeHost'));
      await tester.enterText(find.byKey(const Key('organization-host-address')), 'localhost');
      await tester.pumpAndSettle();
      await _tap(tester, _confirm());
      expect(made.source.writes, isEmpty);
      await tester.enterText(find.byKey(const Key('organization-host-address')), 'build.example.org');
      await tester.enterText(find.byKey(const Key('organization-host-key')), 'ssh-rsa AAAA');
      await tester.pumpAndSettle();
      await _tap(tester, _confirm());
      expect(made.source.writes, isEmpty);
      await tester.enterText(find.byKey(const Key('organization-host-key')), buildHost.hostKey!);
      await tester.enterText(find.byKey(const Key('organization-host-port')), '2200');
      await tester.pumpAndSettle();
      await _tap(tester, _confirm());
      final write = made.source.writes.single;
      expect(write.change, OrganizationChange.changeHost);
      expect(write.input, {
        'host': 'build',
        'address': 'build.example.org',
        'port': '2200',
        'hostKey': buildHost.hostKey,
        'webPort': '8081',
        'gitPort': '8082',
        'matrixPort': '8083',
      });
    });

    // Harm: a host with no forge or homeserver can never have its address changed; or half a forge is written.
    testWidgets('a service taken off the host is written as none, and half a forge is refused', (tester) async {
      final made = await page(tester, 'hana');
      await _tap(tester, _action('changeHost'));
      await tester.enterText(find.byKey(const Key('organization-host-matrix-port')), '');
      await tester.enterText(find.byKey(const Key('organization-host-git-port')), '');
      await tester.pumpAndSettle();
      await _tap(tester, _confirm());
      expect(made.source.writes, isEmpty);
      await tester.enterText(find.byKey(const Key('organization-host-web-port')), '');
      await tester.pumpAndSettle();
      await _tap(tester, _confirm());
      expect(made.source.writes.single.input, {
        'host': 'build',
        'address': buildHost.address,
        'port': '${buildHost.port}',
        'hostKey': buildHost.hostKey,
        'webPort': 'none',
        'gitPort': 'none',
        'matrixPort': 'none',
      });
    });

    // Harm: a host admin reads a project as there when the host holds it back, or an account goes with nobody told.
    testWidgets("a connected host admin reads the host's own word, the day an account goes, and no action on it", (
      tester,
    ) async {
      final connections = FixtureConnections(['build'])
        ..hostProgress = const HostProgress(
          projects: [HostProjectProgress(project: 'demo', state: 'held', why: 'app has unpushed commits')],
          locked: [HostLockedPerson(login: 'rex', purgeOn: '2026-11-09')],
        );
      await page(tester, 'hana', connections: connections);
      expect(find.textContaining('held: app has unpushed commits'), findsOneWidget);
      expect(find.text('rex: locked, account deleted on 2026-11-09'), findsOneWidget);
      expect(_action('giveToken'), findsNothing);
    });

    // Harm: a member's interface asks root, which is not their way in.
    testWidgets('a member asks the host nothing', (tester) async {
      final connections = FixtureConnections(['build']);
      await page(tester, 'mia', connections: connections);
      expect(connections.asked, isEmpty);
    });

    // Harm: a commit nobody allowed reads as a removal, or a refused fetch goes unseen while the host stays behind.
    testWidgets('what the last fetch refused is shown in its words, to judge, and is no removal', (tester) async {
      final connections = FixtureConnections(['build'])
        ..hostProgress = const HostProgress(refused: 'the commit is signed by no key in force');
      await page(tester, 'hana', connections: connections);
      final shown = find.textContaining('the commit is signed by no key in force');
      expect(shown, findsOneWidget);
      final words = tester.widget<Text>(shown).data!;
      expect(words, contains('a commit nobody allowed'), reason: 'it says what the admin has to tell apart');
      expect(words, isNot(startsWith('Removed')));
    });

    testWidgets('a host that refused nothing shows nothing of it', (tester) async {
      final connections = FixtureConnections(['build'])..hostProgress = const HostProgress();
      await page(tester, 'hana', connections: connections);
      expect(find.textContaining('a commit nobody allowed'), findsNothing);
    });

    // Harm: a project stays waiting for a token nobody knows is wanted.
    testWidgets('a host waiting for the token offers it, and reads again after', (tester) async {
      final connections = FixtureConnections(['build'])
        ..hostProgress = const HostProgress(
          projects: [HostProjectProgress(project: 'demo', state: 'waiting-for-token')],
        );
      final gave = <String>[];
      await page(
        tester,
        'hana',
        connections: connections,
        onGiveToken: (host) async {
          gave.add(host);
          connections.hostProgress = const HostProgress();
        },
      );
      expect(find.textContaining('waits for your central token'), findsWidgets);
      await _tap(tester, _action('giveToken'));
      expect(gave, ['build']);
      expect(_action('giveToken'), findsNothing);
    });

    // Harm: a project just put on waits five minutes for a token nobody was asked for.
    testWidgets('putting a project on asks the host to fetch at once', (tester) async {
      final connections = FixtureConnections(['build']);
      final made = await page(tester, 'hana', connections: connections);
      made.source.afterWrite = (write) => organizationFor(
        'hana',
        host: const OrganizationHost(name: 'build', admins: ['hana'], projects: ['demo', 'other']),
      );
      await _tap(tester, _action('addProjectToHost'));
      await _tap(tester, find.byKey(const Key('organization-person')));
      await _tap(tester, find.text('other').hitTestable());
      await _tap(tester, _confirm());
      expect(connections.asked, contains('refresh build'));
    });

    // Harm: Refresh gives no answer, or a refusal is shown as done.
    testWidgets('Refresh asks the host, and a refusal is shown', (tester) async {
      final made = await page(tester, 'hana', connections: FixtureConnections(['build']));
      await _tap(tester, _action('refreshHost'));
      expect(made.connections.asked, contains('refresh build'));
      made.connections.refuseNext = const OrganizationRefused('Connect to build first.');
      await _tap(tester, _action('refreshHost'));
      expect(find.text('Connect to build first.'), findsOneWidget);
    });

    // Harm: a person cannot end a connection, or sees it as ended when it was refused.
    testWidgets('Disconnect ends the connection and offers Connect again', (tester) async {
      final made = await page(tester, 'mia', connections: FixtureConnections(['build']));
      expect(find.textContaining('Connected as mia, with the host key from the organization.'), findsOneWidget);
      await _tap(tester, _action('disconnect/build'));
      expect(made.connections.asked, ['disconnect build']);
      expect(_action('connect/build'), findsOneWidget);
    });

    // Harm: a person sees a blank page for a host the organization has since dropped.
    testWidgets('a host the organization no longer names is said as such', (tester) async {
      await page(tester, 'mia', host: 'gone');
      expect(find.text('acme has no host gone.'), findsOneWidget);
    });
  });
}
