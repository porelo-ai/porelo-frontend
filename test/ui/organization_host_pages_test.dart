import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_host/porelo_host.dart' show HostCardSsh;
import 'package:porelo_frontend/src/app/host_progress.dart';
import 'package:porelo_frontend/src/app/links.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/ui/organization_host_pages.dart';
import 'package:porelo_frontend/src/ui/organization_page.dart';

import '../support/organization_fixtures.dart';
import '../features/support/world.dart' show World;
import 'organization_actions.dart';

Finder _action(String id) => organizationAction(id);
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
  // Harm: a held project's repositories look safe even though their work can be lost with the machine.
  testWidgets('a held project names every taken repository with its central state', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final organization = Organization(FixtureOrganization(organizationFor('hana')));
    final connections = FixtureConnections(['build'])
      ..hostProgress = HostProgress.read('''
{"projects":[{"project":"demo","state":"held","repositories":[
{"repository":"core","state":"taken","central":{"state":"ahead","commits":2}},
{"repository":"api","state":"taken","central":{"state":"up-to-date"}},
{"repository":"web","state":"taken","central":{"state":"moved-on"}},
{"repository":"old","state":"taken"}
]}]}
''');
    addTearDown(organization.dispose);
    addTearDown(connections.dispose);
    await organization.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizationHostPage(
            organization: organization,
            host: 'build',
            connections: connections,
            onBack: () {},
          ),
        ),
      ),
    );
    await World.settle(tester);
    for (final (repository, words) in [
      ('core', '2 commits ahead of central'),
      ('api', 'at central'),
      ('web', 'central moved on'),
      ('old', 'cannot say'),
    ]) {
      final row = find.byKey(ValueKey('organization.central/demo/$repository'));
      expect(find.descendant(of: row, matching: find.text(repository)), findsOneWidget);
      expect(find.descendant(of: row, matching: find.textContaining(words)), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final onPage in [false, true]) {
    group(onPage ? "opening a machine's forge from its page" : "opening a machine's forge from its row", () {
      late List<Uri> opened;

      setUp(() {
        opened = [];
        final previous = openLink;
        openLink = (address) async => opened.add(address);
        addTearDown(() => openLink = previous);
      });

      Future<void> menu(WidgetTester tester, _ForgeConnections connections, {OrganizationView? view}) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        addTearDown(connections.dispose);
        final organization = Organization(FixtureOrganization(view ?? organizationFor('mia')));
        addTearDown(organization.dispose);
        await organization.refresh();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: onPage
                  ? OrganizationHostPage(
                      organization: organization,
                      host: 'build',
                      connections: connections,
                      onBack: () {},
                    )
                  : OrganizationPage(organization: organization, connections: connections, onHost: (_) {}),
            ),
          ),
        );
        await tester.pump();
        final button = find.byTooltip('What can be done with build');
        await tester.ensureVisible(button);
        await tester.pump();
        await tester.tap(button);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Harm: the browser reaches a rejected address or another machine's forge.
      testWidgets('a connected host opens the forwarded address from its own card', (tester) async {
        await menu(tester, _ForgeConnections(connected: true));
        await tester.tap(find.text('Open its forge'));
        await tester.pump();
        expect(opened, [Uri.parse('http://build.localhost:9471/')]);
      });

      // Harm: a browser opens a local port that no longer belongs to this connection.
      testWidgets('a disconnected host keeps the command disabled with its connection reason', (tester) async {
        await menu(tester, _ForgeConnections(connected: false));
        final command = find.ancestor(of: find.text('Open its forge'), matching: find.byType(PopupMenuItem<String>));
        expect(tester.widget<PopupMenuItem<String>>(command).enabled, isFalse);
        expect(find.textContaining('Connect first: the forge is reached through the connection'), findsOneWidget);
        await tester.tap(find.text('Open its forge'));
        await tester.pump();
        expect(opened, isEmpty);
      });

      // Harm: a person is sent to connect to reach a forge the machine does not run.
      testWidgets('a host the organization lists without a forge says so before any connection', (tester) async {
        const plain = OrganizationHost(
          name: 'build',
          address: '203.0.113.7',
          port: 22,
          hostKey: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcH',
          admins: ['mia'],
        );
        await menu(tester, _ForgeConnections(connected: false), view: organizationFor('mia', host: plain));
        expect(find.textContaining('This host has no forge.'), findsOneWidget);
        expect(find.textContaining('Connect first'), findsNothing);
      });

      // Harm: a host running no forge opens an unrelated service on a guessed port.
      testWidgets('a connected host without a forge keeps the command disabled and says why', (tester) async {
        await menu(tester, _ForgeConnections(connected: true, webPort: null));
        final command = find.ancestor(of: find.text('Open its forge'), matching: find.byType(PopupMenuItem<String>));
        expect(tester.widget<PopupMenuItem<String>>(command).enabled, isFalse);
        expect(find.textContaining('This host has no forge.'), findsOneWidget);
        await tester.tap(find.text('Open its forge'));
        await tester.pump();
        expect(opened, isEmpty);
      });

      // Harm: an entry left open through a disconnect opens a port after its forward has ended.
      testWidgets('disconnecting while the menu is open prevents the browser from opening', (tester) async {
        final connections = _ForgeConnections(connected: true);
        await menu(tester, connections);
        await connections.disconnect('build');
        await tester.pump();
        await tester.tap(find.text('Open its forge'));
        await tester.pump();
        expect(opened, isEmpty);
      });

      // Harm: a kept card outlives its tunnel and opens a port whose forward has ended.
      testWidgets('a lost tunnel disables the command even while its card is kept', (tester) async {
        final connections = _ForgeConnections(connected: true).._loseForward();
        await menu(tester, connections);
        final command = find.ancestor(of: find.text('Open its forge'), matching: find.byType(PopupMenuItem<String>));
        expect(tester.widget<PopupMenuItem<String>>(command).enabled, isFalse);
        expect(find.textContaining('Connect first: the forge is reached through the connection'), findsOneWidget);
        await tester.tap(find.text('Open its forge'));
        await tester.pump();
        expect(opened, isEmpty);
      });

      // Harm: an entry left open through a lost tunnel opens a local port without its forward.
      testWidgets('losing the tunnel while the menu is open prevents the browser from opening', (tester) async {
        final connections = _ForgeConnections(connected: true);
        await menu(tester, connections);
        connections._loseForward();
        await tester.pump();
        await tester.tap(find.text('Open its forge'));
        await tester.pump();
        expect(opened, isEmpty);
      });
    });
  }

  group('a machine\'s admin puts a project on it from the organization', () {
    Future<(FixtureOrganization, FixtureConnections)> organization(
      WidgetTester tester, {
      FixtureConnections? connections,
    }) async {
      final fixture = FixtureOrganization(organizationFor('hana'));
      final held = Organization(fixture);
      addTearDown(held.dispose);
      final made = connections ?? FixtureConnections();
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _settle(tester, OrganizationPage(organization: held, connections: made, onHost: (_) {}));
      return (fixture, made);
    }

    // Harm: a project lands on two machines at once, against the rule of one at a time.
    testWidgets('only a project on no machine is offered, among the machines one administers', (tester) async {
      final (source, _) = await organization(tester);
      expect(_action('putOnMachine/demo'), findsNothing);
      await pressOrganizationAction(tester, 'putOnMachine/other');
      await _tap(tester, find.byKey(const Key('organization-person')));
      await _tap(tester, find.text('build').hitTestable());
      await _tap(tester, _confirm());
      final write = source.writes.single;
      expect(write.change, OrganizationChange.addProjectToHost);
      expect(write.input, {'host': 'build', 'project': 'other'});
    });

    // Harm: a whole project put on a machine when one repository of it was meant.
    testWidgets('carrying one repository of a project sends that repository alone', (tester) async {
      final (source, _) = await organization(tester);
      source.projects['other'] = const ProjectView(
        name: 'other',
        revision: 'p2',
        roles: ['admin'],
        repositories: [
          ProjectRepository(name: 'api', address: 'git@forge.example.org:acme/api.git'),
          ProjectRepository(name: 'web', address: 'git@forge.example.org:acme/web.git'),
        ],
      );
      await pressOrganizationAction(tester, 'putOnMachine/other');
      await _tap(tester, find.byKey(const Key('organization-person')));
      await _tap(tester, find.text('build').hitTestable());
      await _tap(tester, find.byKey(const Key('organization-carry-some')));
      await _tap(tester, find.byKey(const Key('organization-carry-repository-api')));
      await _tap(tester, _confirm());
      final write = source.writes.single;
      expect(write.change, OrganizationChange.addProjectToHost);
      expect(write.input, {'host': 'build', 'project': 'other', 'repositories': 'api'});
    });

    // Harm: a machine's admin deletes a room's conversation with no word of it.
    testWidgets('taking one off says what stays until its unpushed work is gone, and what goes then', (tester) async {
      final (source, _) = await organization(tester);
      await pressOrganizationAction(tester, 'takeOffMachine/demo');
      expect(find.textContaining('once it holds no unpushed work'), findsOneWidget);
      expect(find.textContaining('with its conversation'), findsOneWidget);
      await _tap(tester, _confirm());
      final write = source.writes.single;
      expect(write.change, OrganizationChange.removeProjectFromHost);
      expect(write.input, {'host': 'build', 'project': 'demo'});
    });

    // Harm: a project put on a machine with no address waits there for a token that cannot help, and nobody is told.
    testWidgets('a project the store will not put on stays where it was, with the words why', (tester) async {
      final (source, _) = await organization(tester);
      source.refuseNext = const OrganizationRefused('other has no address yet, so no machine can follow it.');
      await pressOrganizationAction(tester, 'putOnMachine/other');
      await _tap(tester, find.byKey(const Key('organization-person')));
      await _tap(tester, find.text('build').hitTestable());
      await _tap(tester, _confirm());
      expect(find.text('other has no address yet, so no machine can follow it.'), findsOneWidget);
    });

    // Harm: a Connect that ended unconnected left nothing to look at but its one sentence.
    testWidgets('the last attempt can be opened until it connects', (tester) async {
      final connections = FixtureConnections();
      connections.lastAttempts['build'] = ConnectAttempt(DateTime(2026), const ['ssh said: no route to host']);
      await organization(tester, connections: connections);
      final open = find.byKey(const ValueKey('organization.attempt/build'));
      await tester.ensureVisible(open);
      await _tap(tester, open);
      expect(find.textContaining('ssh said: no route to host'), findsOneWidget);
      await _tap(tester, find.text('Close'));
    });

    testWidgets('and is gone once it stands connected', (tester) async {
      final connections = FixtureConnections(['build']);
      connections.lastAttempts['build'] = ConnectAttempt(DateTime(2026), const ['The connection is up.']);
      await organization(tester, connections: connections);
      expect(find.byKey(const ValueKey('organization.attempt/build')), findsNothing);
    });

    // Harm: a project just put on waits five minutes for a token nobody was asked for.
    testWidgets('putting one on asks a connected machine to fetch at once', (tester) async {
      final connections = FixtureConnections(['build']);
      final (source, _) = await organization(tester, connections: connections);
      source.afterWrite = (write) => organizationFor(
        'hana',
        host: const OrganizationHost(name: 'build', admins: ['hana'], projects: ['demo', 'other']),
      );
      await pressOrganizationAction(tester, 'putOnMachine/other');
      await _tap(tester, find.byKey(const Key('organization-person')));
      await _tap(tester, find.text('build').hitTestable());
      await _tap(tester, _confirm());
      expect(connections.asked, contains('refresh build'));
    });
  });

  group('the hosts under Machines', () {
    Future<({FixtureConnections connections, List<String> opened})> section(
      WidgetTester tester,
      OrganizationView view, {
      FixtureConnections? connections,
      Future<String?> Function(String host)? onGiveToken,
    }) async {
      final organization = Organization(FixtureOrganization(view));
      addTearDown(organization.dispose);
      final made = connections ?? FixtureConnections();
      final opened = <String>[];
      await _settle(
        tester,
        OrganizationPage(organization: organization, connections: made, onHost: opened.add, onGiveToken: onGiveToken),
      );
      return (connections: made, opened: opened);
    }

    // Harm: *Connect* greys for a moment and returns, with no word, as in the foo test.
    testWidgets('a connect on a machine waiting for its token names that step, beside the button', (tester) async {
      final connections = FixtureConnections()..waiting.add('build');
      final made = await section(tester, organizationFor('hana'), connections: connections);
      await pressOrganizationAction(tester, 'connect/build');
      expect(find.textContaining('your token'), findsWidgets);
      expect(_action('connect/build'), findsNothing, reason: 'the one button that cannot help is gone');
      await tester.tap(find.byKey(const ValueKey('organization.toToken/build')));
      await tester.pumpAndSettle();
      expect(made.opened, ['build']);
    });

    // Harm: the row's *Give it your token…* opens the machine's page, where no token is offered until a live run waits.
    testWidgets("the row's token button opens the token's page for that machine", (tester) async {
      final connections = FixtureConnections()..waiting.add('build');
      final asked = <String>[];
      final made = await section(
        tester,
        organizationFor('hana'),
        connections: connections,
        onGiveToken: (host) async {
          asked.add(host);
          return null;
        },
      );
      await pressOrganizationAction(tester, 'connect/build');
      await tester.tap(find.byKey(const ValueKey('organization.toToken/build')));
      await tester.pumpAndSettle();
      expect(asked, ['build']);
      expect(made.opened, isEmpty);
    });

    // Harm: the one who cannot give it is sent after a button they do not have.
    testWidgets('anyone else reads who it waits for', (tester) async {
      final connections = FixtureConnections()..waiting.add('build');
      await section(tester, organizationFor('mia'), connections: connections);
      await pressOrganizationAction(tester, 'connect/build');
      expect(find.textContaining('waits for its Machine Admin'), findsOneWidget);
      expect(find.byKey(const ValueKey('organization.toToken/build')), findsNothing);
      expect(_action('connect/build'), findsOneWidget, reason: 'they connect again once it is given');
    });

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
      await pressOrganizationAction(tester, 'connect/build');
      expect(made.connections.asked, ['connect build']);
      expect(find.textContaining('connected, ready to work on'), findsOneWidget);
      expect(_action('connect/build'), findsNothing);
    });

    // Harm: a host admin with no project cannot reach the host to manage it.
    testWidgets('a host admin with no project can open their host from Machines', (tester) async {
      final made = await section(tester, organizationFor('olive'));
      final host = find.byKey(const ValueKey('my-host spare'));
      expect(host, findsOneWidget);
      expect(_action('connect/spare'), findsOneWidget);
      await _tap(tester, host);
      expect(made.opened, ['spare']);
    });

    // Harm: a person is offered a host they have nothing to do on.
    testWidgets('a host carrying none of the person\'s projects is not offered', (tester) async {
      await section(tester, organizationFor('mia'));
      expect(find.byKey(const ValueKey('my-host spare')), findsOneWidget, reason: 'everyone reads the list');
      expect(_action('connect/spare'), findsNothing);
    });

    // Harm: a person whose card is not trusted is offered a connection the host refuses.
    testWidgets('a person holding no roles is offered no host', (tester) async {
      await section(tester, organizationFor('rex'));
      expect(_action('connect/build'), findsNothing);
    });

    // Harm: Connect fails with no way to tell why, or no address is mistaken for a broken network.
    testWidgets('a host with no address says so and cannot be connected to', (tester) async {
      await section(tester, organizationFor('olive'));
      expect(find.textContaining('spare is listed, not set up yet.'), findsOneWidget);
      expect(tester.widget<FilledButton>(_action('connect/spare')).onPressed, isNull);
    });

    // Harm: a person is left thinking they are connected, with no idea what to do next.
    testWidgets('a refused Connect shows its words and stays not connected', (tester) async {
      final connections = FixtureConnections()..refuseNext = const OrganizationRefused('The vault is locked.');
      await section(tester, organizationFor('mia'), connections: connections);
      await pressOrganizationAction(tester, 'connect/build');
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
      Future<String?> Function(String host)? onGiveToken,
      Future<String?> Function(String host, String? project)? onStartWork,
      OrganizationHost shown = buildHost,
      void Function(String host)? onPrepare,
      List<({String name, Widget row})>? machineProjects,
    }) async {
      final source = FixtureOrganization(organizationFor(me, moreProjects: moreProjects, host: shown));
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
          onPrepare: onPrepare,
          onStartWork: onStartWork,
          machineProjects: machineProjects,
        ),
      );
      return (source: source, connections: made);
    }

    // Harm: a whole project taken off a machine when one repository of it was meant, its other repositories with it.
    testWidgets('a project carried in part lists its repositories, and one is taken off alone', (tester) async {
      final made = await page(
        tester,
        'hana',
        shown: const OrganizationHost(
          name: 'build',
          admins: ['hana'],
          projects: ['demo', 'other'],
          repositories: {
            'other': ['api'],
          },
        ),
      );
      expect(find.byKey(const ValueKey('organization.carried/other/api')), findsOneWidget);
      expect(find.byKey(const ValueKey('organization.carried/other/web')), findsNothing);
      expect(find.byKey(const ValueKey('organization.carried/demo/demo')), findsNothing, reason: 'demo is whole');

      await _tap(tester, find.byKey(const ValueKey('organization.takeOffRepository/other/api')));
      expect(find.textContaining('takes that key off the central forge'), findsOneWidget);
      await _tap(tester, _confirm());
      final write = made.source.writes.single;
      expect(write.change, OrganizationChange.removeProjectFromHost);
      expect(write.input, {'host': 'build', 'project': 'other', 'repositories': 'api'});
    });

    // Harm: a repository the machine would not let go reads as gone, its refusal said nowhere.
    testWidgets("taking one repository off says the machine's refusal on its page", (tester) async {
      final made = await page(
        tester,
        'hana',
        shown: const OrganizationHost(
          name: 'build',
          admins: ['hana'],
          projects: ['demo', 'other'],
          repositories: {
            'other': ['api'],
          },
        ),
      );
      made.source.refuseNext = const OrganizationRefused('api is carried whole by another rule.');
      await _tap(tester, find.byKey(const ValueKey('organization.takeOffRepository/other/api')));
      await _tap(tester, _confirm());
      expect(find.textContaining('api is carried whole by another rule.'), findsOneWidget);
    });

    // Harm: unpushed work holding a removed project on a machine disappears from the only list its admin can act on.
    testWidgets('the read-only list keeps what the machine carries until it is gone, for a connected admin only', (
      tester,
    ) async {
      final connections = FixtureConnections(['build'])
        ..hostProgress = const HostProgress(
          projects: [
            HostProjectProgress(project: 'retired', state: 'held', why: 'app and docs have unpushed commits'),
            HostProjectProgress(project: 'pending', state: 'carried'),
          ],
        );
      final made = await page(tester, 'hana', connections: connections);
      expect(find.text('retired'), findsOneWidget);
      expect(find.text('pending'), findsOneWidget);
      final row = find.ancestor(of: find.text('retired'), matching: find.byType(ListTile));
      expect(
        find.descendant(of: row, matching: find.textContaining('held: app and docs have unpushed commits')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.textContaining('being taken off, which can take up to five minutes')),
        findsOneWidget,
      );
      expect(tester.widget<ListTile>(row).trailing, isNull, reason: 'the machine list is read only');
      expect(tester.widget<ListTile>(row).onTap, isNull);

      connections.hostProgress = const HostProgress(
        projects: [HostProjectProgress(project: 'pending', state: 'carried')],
      );
      await pressOrganizationAction(tester, 'refreshHost');
      expect(find.text('retired'), findsNothing);
      expect(find.text('pending'), findsOneWidget);
      await pressOrganizationAction(tester, 'disconnect/build');
      expect(find.text('pending'), findsNothing, reason: 'disconnected, only the organization supplies the rows');
      expect(find.text('demo'), findsOneWidget);
      expect(made.source.writes, isEmpty);

      final member = FixtureConnections(['build'])..hostProgress = connections.hostProgress;
      await page(tester, 'mia', connections: member);
      expect(find.text('pending'), findsNothing);
      expect(find.text('demo'), findsOneWidget);
      expect(member.asked, isEmpty, reason: 'a member never asks root for the machine list');
    });

    // Harm: a project the machine refused shows no reason, so its admin cannot tell what to change.
    testWidgets('a project the machine refused says why, and one being put on is not left as a bare word', (
      tester,
    ) async {
      final connections = FixtureConnections(['build'])
        ..hostProgress = const HostProgress(
          projects: [
            HostProjectProgress(project: 'demo', state: 'pending'),
            HostProjectProgress(project: 'refused-one', state: 'refused', why: 'its file names no signing key'),
            HostProjectProgress(project: 'refused-two', state: 'refused'),
            HostProjectProgress(project: 'leaving', state: 'pending'),
          ],
        );
      await page(tester, 'hana', connections: connections);
      Finder onRow(String project, String words) => find.descendant(
        of: find.ancestor(of: find.text(project), matching: find.byType(ListTile)),
        matching: find.textContaining(words),
      );
      expect(onRow('refused-one', 'refused by the machine: its file names no signing key'), findsOneWidget);
      expect(onRow('refused-two', 'refused by the machine'), findsOneWidget);
      expect(onRow('demo', 'being put on'), findsOneWidget);
      expect(onRow('leaving', 'being taken off'), findsOneWidget);
      expect(
        onRow('leaving', 'being put on'),
        findsNothing,
        reason: 'the host says pending of a project going either way',
      );
    });

    // Harm: a project carried with something wrong reads as a project with nothing wrong.
    testWidgets('a project the machine carries with a reason says the reason', (tester) async {
      final connections = FixtureConnections(['build'])
        ..hostProgress = const HostProgress(
          projects: [
            HostProjectProgress(project: 'demo', state: 'carried', why: 'the host card names no forge git port'),
          ],
        );
      await page(tester, 'hana', connections: connections);
      expect(
        find.descendant(
          of: find.ancestor(of: find.text('demo'), matching: find.byType(ListTile)),
          matching: find.textContaining('on the machine: the host card names no forge git port'),
        ),
        findsOneWidget,
      );
    });

    // Harm: *Change address and key…* is pressed first for a machine still to be rented, which has no
    // address anyone could enter.
    testWidgets('a machine with no address offers preparing it, and entering them by hand second', (tester) async {
      String? prepared;
      await page(tester, 'olive', host: 'spare', onPrepare: (host) => prepared = host);
      expect(find.text('Change address and key…'), findsNothing);
      expect(find.text('Enter address and key…'), findsOneWidget);
      await pressOrganizationAction(tester, 'prepareHost');
      expect(prepared, 'spare');
    });

    testWidgets('a machine with an address offers changing them, and not preparing it', (tester) async {
      await page(tester, 'hana', onPrepare: (_) {});
      expect(find.text('Change address and key…'), findsOneWidget);
      expect(_action('prepareHost'), findsNothing);
    });

    // Harm: a person who may not manage a host is offered what the store refuses.
    testWidgets('a member sees the host and their connection, and no management', (tester) async {
      await page(tester, 'mia');
      expect(find.textContaining('203.0.113.7:22'), findsOneWidget);
      expect(find.text('demo'), findsOneWidget);
      expect(find.text('hana'), findsOneWidget);
      for (final id in ['changeHost', 'refreshHost', 'addHostAdmin', 'removeHostAdmin/hana']) {
        expect(_action(id), findsNothing, reason: id);
      }
      expect(_action('connect/build'), findsOneWidget);
    });

    // Harm: a host loses its last admin, or a refusal is lost.
    // Harm: a button that can only fail, on the row of the one person who must stay.
    testWidgets('the last host admin is offered no removal', (tester) async {
      await page(tester, 'hana');
      expect(_action('removeHostAdmin/hana'), findsNothing);
    });

    testWidgets('removing one of two host admins shows the refusal', (tester) async {
      final made = await page(
        tester,
        'hana',
        shown: const OrganizationHost(name: 'build', admins: ['hana', 'pat']),
      );
      made.source.refuseNext = const OrganizationRefused('The store refused this.');
      await pressOrganizationAction(tester, 'removeHostAdmin/pat');
      await _tap(tester, _confirm());
      expect(find.textContaining('The store refused this.'), findsWidgets);
      expect(made.source.writes, hasLength(1));
    });

    // Harm: a host admin who made a backup key sees no sign of it.
    testWidgets('a host admin with a backup key says so', (tester) async {
      await page(
        tester,
        'hana',
        shown: const OrganizationHost(
          name: 'build',
          admins: ['hana'],
          adminKeys: [HostAdminKey(login: 'hana', key: 'k', backup: true)],
        ),
      );
      expect(find.textContaining('has a backup key'), findsOneWidget);
    });

    // Harm: a person is named a host admin who cannot act, or who already is one.
    testWidgets('adding a host admin offers people holding roles who are not yet one', (tester) async {
      final made = await page(tester, 'hana');
      await pressOrganizationAction(tester, 'addHostAdmin');
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
      await pressOrganizationAction(tester, 'changeHost');
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
      await pressOrganizationAction(tester, 'changeHost');
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

    // Harm: a project still waits after the token was given, and the page only asks for the token again.
    testWidgets('why a project waits is said beside it', (tester) async {
      final connections = FixtureConnections(['build'])
        ..hostProgress = const HostProgress(
          projects: [HostProjectProgress(project: 'demo', state: 'waiting-for-token', why: 'the helper exited 69')],
        );
      await page(tester, 'hana', connections: connections);
      expect(find.textContaining('the helper exited 69'), findsOneWidget);
    });

    // Harm: a host admin is sent to give a token that cannot help, when the project's admin has something to do.
    testWidgets('a project the host has no address for offers no token, and says whose it is', (tester) async {
      final connections = FixtureConnections(['build'])
        ..hostProgress = const HostProgress(
          projects: [HostProjectProgress(project: 'demo', state: 'waiting-for-token', hasNoAddress: true)],
        );
      await page(tester, 'hana', connections: connections);
      expect(find.textContaining("project's admin"), findsOneWidget);
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
          return null;
        },
      );
      await pressOrganizationAction(tester, 'giveToken');
      expect(gave, ['build']);
      expect(_action('giveToken'), findsNothing);
    });

    // Harm: the button seems dead, as in the foo test: a press with no token must leave words on the page.
    testWidgets('a press that gives no token says why beside the button, and a new press clears it', (tester) async {
      final connections = FixtureConnections(['build'])..hostProgress = const HostProgress(waitsForToken: true);
      String? answer = 'No GitHub token is kept on this computer.';
      await page(tester, 'hana', connections: connections, onGiveToken: (_) async => answer);
      await pressOrganizationAction(tester, 'giveToken');
      expect(find.byKey(const ValueKey('organization.tokenWhy')), findsOneWidget);
      expect(find.text('No GitHub token is kept on this computer.'), findsOneWidget);
      answer = null;
      await pressOrganizationAction(tester, 'giveToken');
      expect(find.byKey(const ValueKey('organization.tokenWhy')), findsNothing);
    });

    // Harm: a connection that dropped reads as an account not made yet, and offers no way back.
    testWidgets('a kept connection that is down says so, and offers Connect', (tester) async {
      final connections = _DownConnections(['build']);
      await page(tester, 'hana', connections: connections);
      final said = tester.widget<Text>(find.byKey(const ValueKey('organization.connectionWords'))).data!;
      expect(said, contains('is down'));
      expect(_action('connect/build'), findsOneWidget);
    });

    // Harm: the row says one thing and the page another, as in the foo test: "not connected yet" and "Connected".
    testWidgets('the page does not say Connected while its connection is not up', (tester) async {
      final connections = FixtureConnections(['build'])..waiting.add('build');
      await page(tester, 'hana', connections: connections);
      final said = tester.widget<Text>(find.byKey(const ValueKey('organization.connectionWords'))).data!;
      expect(said, isNot(startsWith('Connected')));
    });

    // Harm: the token is given and the person still has no connection, with a button that says Disconnect.
    testWidgets('a host waiting for its first token says so, and the connection comes up after it', (tester) async {
      final connections = FixtureConnections(['build'])..hostProgress = const HostProgress(waitsForToken: true);
      await page(
        tester,
        'hana',
        connections: connections,
        onGiveToken: (_) async {
          connections.hostProgress = const HostProgress();
          return null;
        },
      );
      expect(find.textContaining('makes your account once it has read the organization'), findsOneWidget);
      await pressOrganizationAction(tester, 'giveToken');
      expect(connections.asked, contains('connect build'));
      expect(_action('giveToken'), findsNothing);
    });

    // Harm: a person cannot see what is on the machine for a wall of the same sentence.
    testWidgets('a project names its repositories on the machine first, and counts the rest once', (tester) async {
      const why = 'no central address, so this host cannot take it; name one in the project file for a task here';
      final connections = FixtureConnections(['build'])
        ..hostProgress = HostProgress(
          projects: [
            HostProjectProgress(
              project: 'demo',
              state: 'carried',
              why: List.filled(15, why).join('; '),
              repositories: [
                (repository: 'core', state: 'taken', why: null, central: null),
                (repository: 'sluice', state: 'taken', why: null, central: null),
                for (var i = 0; i < 15; i++) (repository: 'library-$i', state: 'no-central', why: why, central: null),
              ],
            ),
          ],
        );
      await page(tester, 'hana', connections: connections);
      expect(find.textContaining('on the machine: core, sluice'), findsOneWidget);
      expect(find.text('15 repositories name no central address, so the machine does not take them'), findsOneWidget);
      expect(find.textContaining(why), findsNothing, reason: 'the reason is opened on demand');
      await _tap(tester, find.byKey(const ValueKey('organization.notTaken/demo/no-central')));
      expect(find.text(why), findsOneWidget, reason: 'said once, not per repository');
    });

    // Harm: a fetch the machine refused is said as applied.
    testWidgets("Fetch now says the machine's own refusal, not that it applied", (tester) async {
      final connections = FixtureConnections(['build'])
        ..hostProgress = const HostProgress(refused: 'the commit is signed by no key in force');
      await page(tester, 'hana', connections: connections);
      await pressOrganizationAction(tester, 'refreshHost');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('organization.refreshWhy'))).data,
        'build did not apply the organization: the commit is signed by no key in force',
      );
    });

    // Harm: a fetch gives no answer, or a refusal is shown as done.
    testWidgets('Fetch now asks the machine, and a refusal is shown', (tester) async {
      final made = await page(tester, 'hana', connections: FixtureConnections(['build']));
      await pressOrganizationAction(tester, 'refreshHost');
      expect(made.connections.asked, contains('refresh build'));
      made.connections.refuseNext = const OrganizationRefused('Connect to build first.');
      await pressOrganizationAction(tester, 'refreshHost');
      // Beside the button pressed, where the person looks, not at the page's head scrolled away.
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('organization.refreshWhy'))).data,
        'Connect to build first.',
      );
    });

    // Harm: a person cannot tell whether this computer is connected, what that means, or how to go on from it.
    testWidgets('the top of the page says where one stands, and leads on', (tester) async {
      final started = <(String, String?)>[];
      await page(
        tester,
        'mia',
        connections: FixtureConnections(),
        onStartWork: (host, project) async {
          started.add((host, project));
          return null;
        },
      );
      expect(find.textContaining('This computer has no connection to build yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('organization.startWork/build')), findsNothing);
      await pressOrganizationAction(tester, 'connect/build');
      expect(find.textContaining('Connected as mia. Ready to work on: demo.'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('organization.startWork/build')));
      expect(started, [('build', 'demo')]);
    });

    // Harm: a machine that says it is ready for a project leads into the Default project, asking for an address.
    testWidgets('Start work names the one project and starts in it', (tester) async {
      final started = <String?>[];
      await page(
        tester,
        'mia',
        connections: FixtureConnections(['build']),
        onStartWork: (_, project) async {
          started.add(project);
          return null;
        },
      );
      expect(find.text('Start work in demo'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('organization.startWork/build')));
      expect(started, ['demo']);
    });

    // Harm: with several projects on a machine, the person is taken into one they did not choose.
    testWidgets('with several projects Start work asks which, and Default only by its name', (tester) async {
      final started = <String?>[];
      await page(
        tester,
        'mia',
        connections: FixtureConnections(['build']),
        moreProjects: const [
          OrganizationProject(name: 'other', members: ['mia'], admins: [], host: 'build'),
        ],
        onStartWork: (_, project) async {
          started.add(project);
          return null;
        },
      );
      expect(find.text('Start work…'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('organization.startWork/build')));
      expect(started, isEmpty);
      expect(find.byKey(const ValueKey('organization.startWorkIn/default')), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('organization.startWorkIn/other')));
      expect(started, ['other']);
    });

    // Harm: the press seems to do nothing, and the person presses again or gives up.
    testWidgets('a start that cannot happen says why beside the button', (tester) async {
      await page(
        tester,
        'mia',
        connections: FixtureConnections(['build']),
        onStartWork: (_, _) async => 'build does not list demo yet.',
      );
      await _tap(tester, find.byKey(const ValueKey('organization.startWork/build')));
      expect(find.text('build does not list demo yet.'), findsOneWidget);
    });

    // Harm: a page tells a person both that a project is on the machine and that none is.
    testWidgets("the machine's projects and the organization's are one list, each saying where it comes from", (
      tester,
    ) async {
      await page(tester, 'mia', machineProjects: [(name: 'default', row: const Text('the machine lists default'))]);
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Projects on this machine'), findsNothing);
      expect(find.text('the machine lists default'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('organization.projectSource/default'))).data,
        startsWith('Listed by the machine'),
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('organization.projectSource/demo'))).data,
        startsWith('From the organization'),
      );
      expect(find.textContaining('No projects on this machine yet'), findsNothing);
    });

    // Harm: a person looks for Start work with nothing saying why it is not there.
    testWidgets('a page that offers no Start work says what stands in its way', (tester) async {
      await page(tester, 'mia', connections: FixtureConnections(), onStartWork: (_, _) async => null);
      expect(find.byKey(const ValueKey('organization.startWork/build')), findsNothing);
      expect(find.byKey(const ValueKey('organization.noStartWhy')), findsOneWidget);
    });

    // Harm: a press that shows nothing for a minute is pressed again, and starts a second piece of work.
    testWidgets('Start work shows it is starting until its answer, and a second press sends nothing', (tester) async {
      final answer = Completer<String?>();
      var asked = 0;
      await page(
        tester,
        'mia',
        connections: FixtureConnections(['build']),
        onStartWork: (_, _) {
          asked++;
          return answer.future;
        },
      );
      final start = find.byKey(const ValueKey('organization.startWork/build'));
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();
      await tester.tap(start);
      await tester.pump();
      expect(find.textContaining('Starting work on build'), findsOneWidget);
      await tester.tap(start, warnIfMissed: false);
      await tester.pump();
      expect(asked, 1);
      answer.complete('build does not list demo yet.');
      await tester.pumpAndSettle();
      expect(find.textContaining('Starting work on build'), findsNothing);
      expect(find.text('build does not list demo yet.'), findsOneWidget);
    });

    // Harm: a person cannot end a connection, or sees it as ended when it was refused.
    testWidgets('Disconnect ends the connection and offers Connect again', (tester) async {
      final made = await page(tester, 'mia', connections: FixtureConnections(['build']));
      expect(find.textContaining('Connected as mia.'), findsOneWidget);
      await pressOrganizationAction(tester, 'disconnect/build');
      expect(made.connections.asked, ['disconnect build']);
      expect(_action('connect/build'), findsOneWidget);
    });

    // Harm: a person sees a blank page for a host the organization has since dropped.
    testWidgets('a host the organization no longer names is said as such', (tester) async {
      await page(tester, 'mia', host: 'gone');
      expect(find.text('acme has no machine gone.'), findsOneWidget);
    });
  });
}

class _DownConnections extends FixtureConnections {
  _DownConnections(super.hosts);

  @override
  bool up(String host) => false;
}

class _ForgeConnections extends FixtureConnections {
  _ForgeConnections({required bool connected, int? webPort = 9471})
    : _card = HostCardSsh(
        name: 'build',
        address: buildHost.address!,
        sshPort: buildHost.port!,
        hostKey: buildHost.hostKey!,
        login: 'mia',
        publicKey: buildHost.hostKey!,
        webPort: webPort,
      ),
      super(connected ? ['build'] : []);

  final HostCardSsh _card;
  bool _forwardUp = true;

  void _loseForward() {
    _forwardUp = false;
    notifyListeners();
  }

  @override
  bool up(String host) => _forwardUp && super.up(host);

  @override
  String? forgeUrl(String host) => host == _card.name ? _card.forgeUrl : null;
}
