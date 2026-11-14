import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_host/porelo_host.dart' show HostCardSsh;
import 'package:porelo_frontend/src/app/host_progress.dart';
import 'package:porelo_frontend/src/app/links.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/ui/organization_host_pages.dart';
import 'package:porelo_frontend/src/ui/placing_project_dialog.dart' show GiveHostToken;
import 'package:porelo_frontend/src/ui/organization_page.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';
import 'package:porelo_frontend/src/ui/filtered_list_section.dart';

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
        // On the page it is a button in sight; on the row it stays in the row's menu.
        if (onPage) return;
        final button = find.byTooltip('What can be done with build');
        await tester.ensureVisible(button);
        await tester.pump();
        await tester.tap(button);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      bool offered(WidgetTester tester) => onPage
          ? tester.widget<ButtonStyleButton>(find.byKey(const ValueKey('organization.openForge/build'))).onPressed !=
                null
          : tester
                .widget<PopupMenuItem<String>>(
                  find.ancestor(of: find.text('Open its forge'), matching: find.byType(PopupMenuItem<String>)),
                )
                .enabled;

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
        expect(offered(tester), isFalse);
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
        expect(offered(tester), isFalse);
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
        expect(offered(tester), isFalse);
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

  group("a forge that stopped answering through this computer's forward", () {
    late List<Uri> opened;

    setUp(() {
      opened = [];
      final previous = openLink;
      openLink = (address) async => opened.add(address);
      addTearDown(() => openLink = previous);
    });

    Future<_DeadForge> page(WidgetTester tester, {required bool answers, bool onRow = false, bool heals = true}) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final connections = _DeadForge(answers: answers)..heals = heals;
      addTearDown(connections.dispose);
      openLink = (address) async {
        opened.add(address);
        connections.order.add('open');
      };
      final organization = Organization(FixtureOrganization(organizationFor('mia')));
      addTearDown(organization.dispose);
      await organization.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: onRow
                ? OrganizationPage(organization: organization, connections: connections, onHost: (_) {})
                : OrganizationHostPage(
                    organization: organization,
                    host: 'build',
                    connections: connections,
                    onBack: () {},
                  ),
          ),
        ),
      );
      await World.settle(tester);
      return connections;
    }

    const dead = "The host's forge gives no answer through this computer's forward";

    // Harm: the page says Connected while its forge answers nothing, and the person is left with an empty browser tab.
    testWidgets('the page says so, and Open its forge raises the forward anew before opening', (tester) async {
      final connections = await page(tester, answers: false);
      expect(find.textContaining(dead), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('organization.openForge/build')));
      await World.settle(tester);
      expect(connections.raised, ['build'], reason: 'raised anew first');
      expect(opened, [Uri.parse('http://build.localhost:9471/')], reason: 'then opened');
      expect(connections.order, ['raise', 'open'], reason: 'the forward before the browser');
      expect(find.textContaining(dead), findsNothing, reason: 'it answers again');
    });

    // Harm: a forge that answers has its working forward taken down for nothing.
    testWidgets('a forge that answers is opened without raising anything', (tester) async {
      final connections = await page(tester, answers: true);
      expect(find.textContaining(dead), findsNothing);
      await tester.tap(find.byKey(const ValueKey('organization.openForge/build')));
      await World.settle(tester);
      expect(connections.raised, isEmpty);
      expect(opened, [Uri.parse('http://build.localhost:9471/')]);
    });

    // Harm: a forward that cannot be raised again opens nothing and says nothing.
    testWidgets('a forward that cannot be raised anew says why beside the button', (tester) async {
      final connections = await page(tester, answers: false)
        ..refuseRaise = true;
      await tester.tap(find.byKey(const ValueKey('organization.openForge/build')));
      await World.settle(tester);
      expect(find.text('ssh said no'), findsOneWidget);
      expect(connections.raised, ['build']);
      expect(find.textContaining(dead), findsOneWidget);
    });

    // Harm: a forward raised anew in vain leaves the person clicking again for a cause that is on the host.
    testWidgets('a forge still dead after the raise says its cause is on the host', (tester) async {
      await page(tester, answers: false, heals: false);
      await tester.tap(find.byKey(const ValueKey('organization.openForge/build')));
      await World.settle(tester);
      expect(find.textContaining('still gives no answer'), findsOneWidget);
      expect(find.textContaining('its cause is on the host'), findsOneWidget);
    });

    // Harm: a raise that fails in some other way escapes as an unhandled error.
    testWidgets('a raise that fails otherwise is said, never thrown', (tester) async {
      (await page(tester, answers: false)).failOtherwise = true;
      await tester.tap(find.byKey(const ValueKey('organization.openForge/build')));
      await World.settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('could not be raised anew'), findsOneWidget);
    });

    // Harm: the row's menu raises in vain and says nothing of the refusal.
    for (final otherwise in [false, true]) {
      testWidgets("the row's Open its forge says a ${otherwise ? 'failed' : 'refused'} raise", (tester) async {
        final connections = await page(tester, answers: false, onRow: true)
          ..refuseRaise = !otherwise
          ..failOtherwise = otherwise;
        final menu = find.byTooltip('What can be done with build');
        await tester.ensureVisible(menu);
        await tester.pump();
        await tester.tap(menu);
        await World.settle(tester);
        await tester.tap(find.text('Open its forge'));
        await World.settle(tester);
        expect(tester.takeException(), isNull);
        expect(connections.raised, ['build']);
        expect(find.textContaining(otherwise ? 'could not be raised anew' : 'ssh said no'), findsOneWidget);
      });
    }
  });

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
      GiveHostToken? onGiveToken,
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

    // Harm: the placing dialog goes on saying the machine waits, and offers the token again, after it was given there.
    testWidgets('the placing dialog hears that the token was given from it', (tester) async {
      final connections = FixtureConnections(['build'])
        ..hostProgress = HostProgress.read('{"projects":[{"project":"split","state":"waiting-for-token"}]}');
      await connections.progress('build');
      await section(
        tester,
        organizationFor(
          'hana',
          host: const OrganizationHost(
            name: 'build',
            admins: ['hana'],
            projects: ['demo', 'split'],
            repositories: {
              'split': ['split-api'],
            },
          ),
          moreProjects: const [
            OrganizationProject(name: 'split', admins: ['hana'], host: 'build'),
          ],
        ),
        connections: connections,
        onGiveToken: (host, {atOnce = false}) async {
          connections.hostProgress = HostProgress.read(
            '{"projects":[{"project":"split","state":"carried","repositories":[]}]}',
          );
          // As the token's step does once the machine took it.
          await connections.progress(host);
          return null;
        },
      );
      await pressOrganizationAction(tester, 'putOnMachine/split');
      final give = find.byKey(const ValueKey('organization-carry-give-token build'));
      expect(give, findsOneWidget);
      await tester.tap(give);
      await tester.pumpAndSettle();
      expect(give, findsNothing);
    });

    // Harm: a machine whose one project of this person's waits for the token reads as ready to work on, and as
    // carrying it.
    testWidgets('a machine waiting for the token for a project is not ready to work on it', (tester) async {
      final connections = FixtureConnections(['build'])
        ..hostProgress = HostProgress.read('{"projects":[{"project":"demo","state":"waiting-for-token"}]}');
      await connections.progress('build');
      await section(
        tester,
        organizationFor(
          'pat',
          host: const OrganizationHost(name: 'build', admins: ['pat'], projects: ['demo']),
        ),
        connections: connections,
      );
      final row = find.byKey(const ValueKey('organization-machine build'));
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.textContaining('ready to work on')), findsNothing);
      expect(find.descendant(of: row, matching: find.textContaining('carries demo')), findsNothing);
      expect(find.descendant(of: row, matching: find.textContaining('waits for your')), findsOneWidget);
    });

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
        onGiveToken: (host, {atOnce = false}) async {
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

    // Harm: a machine just prepared that waits for its first token makes no account however long one waits, and its
    // Machine Admin was shown a wait instead of the token to give.
    testWidgets('a machine just prepared that waits for its token offers the token, not a wait', (tester) async {
      final connections = FixtureConnections(['build'])
        ..waiting.add('build')
        ..admitting.add('build');
      await section(tester, organizationFor('hana'), connections: connections);
      expect(find.byKey(const ValueKey('organization.toToken/build')), findsOneWidget);
    });
  });

  group('a host\'s page', () {
    Future<({FixtureOrganization source, FixtureConnections connections})> page(
      WidgetTester tester,
      String me, {
      FixtureConnections? connections,
      String host = 'build',
      List<OrganizationProject> moreProjects = const [],
      GiveHostToken? onGiveToken,
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

    // Harm: a machine's explicit refusal reads as unknown, obscuring what prevents work there.
    for (final (state, words) in [
      ('carried', 'Carried'),
      ('pending', 'Being put on'),
      ('waiting-for-token', 'Waiting for your token'),
      ('held', 'Held'),
      ('refused', 'Refused'),
      // A word of a later host, shown as it comes.
      ('future-state', 'future-state'),
    ]) {
      testWidgets('the project chip keeps the host state $state and stands beside its name', (tester) async {
        final made = await page(
          tester,
          'hana',
          connections: FixtureConnections(['build'])
            ..hostProgress = HostProgress(
              projects: [HostProjectProgress(project: 'demo', state: state)],
            ),
        );
        final source = find.byKey(const ValueKey('organization.projectSource/demo'));
        final row = find.ancestor(of: source, matching: find.byType(ListTile)).first;
        final chip = find.descendant(of: row, matching: find.widgetWithText(Chip, words));
        expect(chip, findsOneWidget);
        final name = find.descendant(of: row, matching: find.text('demo'));
        expect(tester.getRect(chip).left, greaterThan(tester.getRect(name).right));
        expect(find.descendant(of: row, matching: find.widgetWithText(Chip, 'not read')), findsNothing);
        await made.connections.disconnect('build');
        await tester.pumpAndSettle();
        expect(chip, findsOneWidget, reason: 'losing contact keeps the state already read');
      });
    }

    // Harm: a machine admin's standing is detached from the person at the tablet boundary.
    // The card is the window less the page's padding (24): 503 gives a 479 card, 504 a 480 one.
    for (final window in [503.0, 504.0]) {
      testWidgets('a Machine Admin chip follows the full card width: $window', (tester) async {
        await page(tester, 'hana');
        tester.view.physicalSize = Size(window, 1600);
        await tester.pumpAndSettle();
        final row = find.ancestor(of: find.text('hana (you)'), matching: find.byType(ListTile));
        await tester.ensureVisible(row);
        await World.settle(tester);
        final section = find.byWidgetPredicate(
          (widget) => widget is FilteredListSection && widget.storageId == 'host-admins build',
        );
        expect(
          tester.getSize(section).width,
          window - 24,
          reason: 'the chip follows the full card, after page padding',
        );
        final name = tester.getRect(find.text('hana (you)'));
        final chip = tester.getRect(find.descendant(of: row, matching: find.byType(Chip)));
        if (window == 504) {
          expect(chip.left, greaterThanOrEqualTo(name.right));
        } else {
          expect(chip.top, greaterThanOrEqualTo(name.bottom));
        }
        expect(tester.takeException(), isNull);
      });
    }

    // Harm: phone setup and membership actions have no visible target identity.
    testWidgets('a phone keeps the host and inner section names', (tester) async {
      await page(tester, 'hana');
      tester.view.physicalSize = const Size(390, 1600);
      await tester.pumpAndSettle();
      for (final title in ['build', 'Projects', 'Machine Admins']) {
        final text = find.byWidgetPredicate(
          (widget) => widget is Text && widget.key == const Key('leaf-title') && widget.data == title,
        );
        await tester.ensureVisible(text);
        expect(text.hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

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
        onGiveToken: (host, {atOnce = false}) async {
          gave.add(host);
          connections.hostProgress = const HostProgress();
          return null;
        },
      );
      await pressOrganizationAction(tester, 'giveToken');
      expect(gave, ['build']);
      expect(_action('giveToken'), findsNothing);
    });

    // Harm: a repository of a project its machine waits for the token for reads as carried there alone.
    testWidgets('a repository carried alone of a waiting project is not called carried', (tester) async {
      final connections = FixtureConnections(['build'])
        ..hostProgress = HostProgress.read('{"projects":[{"project":"split","state":"waiting-for-token"}]}');
      await page(
        tester,
        'hana',
        connections: connections,
        moreProjects: const [
          OrganizationProject(name: 'split', admins: ['hana'], host: 'build'),
        ],
        shown: const OrganizationHost(
          name: 'build',
          admins: ['hana'],
          projects: ['demo', 'split'],
          repositories: {
            'split': ['split-api'],
          },
        ),
      );
      final row = find.byKey(const ValueKey('organization.carried/split/split-api'));
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.textContaining('carried')), findsNothing);
      expect(find.descendant(of: row, matching: find.textContaining('waits for your')), findsOneWidget);
    });

    // Harm: while the machine waits for the token for one new repository, the ones it has taken read as waiting and
    // their project as not ready to work on (seen live).
    testWidgets('a waiting project with a repository taken is ready to work on, and that repository is carried', (
      tester,
    ) async {
      final connections = FixtureConnections(['build'])
        ..hostProgress = HostProgress.read(
          '{"projects":[{"project":"split","state":"waiting-for-token","why":"split-web: waits for a central token",'
          '"repositories":[{"repository":"split-api","state":"taken","central":{"state":"up-to-date"}},'
          '{"repository":"split-web","state":"waiting"}]}]}',
        );
      await connections.progress('build');
      await page(
        tester,
        'hana',
        connections: connections,
        moreProjects: const [
          OrganizationProject(name: 'split', admins: ['hana'], host: 'build'),
        ],
        shown: const OrganizationHost(
          name: 'build',
          admins: ['hana'],
          projects: ['split'],
          repositories: {
            'split': ['split-api', 'split-web'],
          },
        ),
      );
      await tester.pumpAndSettle();
      final taken = find.byKey(const ValueKey('organization.carried/split/split-api'));
      expect(find.descendant(of: taken, matching: find.textContaining('carried here alone')), findsOneWidget);
      expect(find.descendant(of: taken, matching: find.textContaining('waits for your')), findsNothing);
      final waiting = find.byKey(const ValueKey('organization.carried/split/split-web'));
      expect(find.descendant(of: waiting, matching: find.textContaining('waits for your')), findsOneWidget);
      final said = tester.widget<Text>(find.byKey(const ValueKey('organization.connectionWords'))).data!;
      expect(said, contains('Ready to work on: split'));
      expect(said, isNot(contains('Waiting before build takes them: split')));
    });

    // Harm: the machine's page goes on saying it waits for the token, and offers it again, after it was given from
    // elsewhere and the machine said so.
    testWidgets('the page hears that the machine no longer waits, wherever that was asked', (tester) async {
      final connections = FixtureConnections(['build'])..hostProgress = const HostProgress(waitsForToken: true);
      await page(tester, 'hana', connections: connections);
      expect(_action('giveToken'), findsOneWidget);
      connections.hostProgress = const HostProgress();
      await connections.progress('build');
      await tester.pumpAndSettle();
      expect(_action('giveToken'), findsNothing);
    });

    // Harm: a member who was the machine's admin is kept from their project by a wait the machine told them of
    // before, which nobody may read to them now.
    testWidgets('a wait read as Machine Admin is not kept once the role is gone', (tester) async {
      final connections = FixtureConnections(['build'])
        ..hostProgress = HostProgress.read('{"projects":[{"project":"demo","state":"waiting-for-token"}]}');
      final made = await page(
        tester,
        'mia',
        connections: connections,
        shown: const OrganizationHost(name: 'build', admins: ['mia'], projects: ['demo']),
      );
      String said() => tester.widget<Text>(find.byKey(const ValueKey('organization.connectionWords'))).data!;
      expect(said(), isNot(contains('Ready to work on: demo')));
      made.source.view = organizationFor('mia');
      await tester.widget<OrganizationHostPage>(find.byType(OrganizationHostPage)).organization.refresh();
      await tester.pumpAndSettle();
      expect(said(), contains('Ready to work on: demo'));
    });

    // Harm: a token given from the machine's page asks the machine as root again, where the token's own step asked it
    // already, a second login its host counts.
    testWidgets('a token given from the page asks the machine once', (tester) async {
      final connections = FixtureConnections(['build'])..hostProgress = const HostProgress(waitsForToken: true);
      await page(
        tester,
        'hana',
        connections: connections,
        onGiveToken: (host, {atOnce = false}) async {
          connections.hostProgress = const HostProgress();
          // As the token's step does once the machine took it.
          await connections.progress(host);
          return null;
        },
      );
      connections.asked.clear();
      await pressOrganizationAction(tester, 'giveToken');
      expect(connections.asked.where((each) => each.startsWith('progress')), ['progress build']);
      expect(_action('giveToken'), findsNothing, reason: 'it no longer waits');
    });

    // Harm: the button seems dead, as in the foo test: a press with no token must leave words on the page.
    testWidgets('a press that gives no token says why beside the button, and a new press clears it', (tester) async {
      final connections = FixtureConnections(['build'])..hostProgress = const HostProgress(waitsForToken: true);
      String? answer = 'No GitHub token is kept on this computer.';
      await page(tester, 'hana', connections: connections, onGiveToken: (_, {atOnce = false}) async => answer);
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
        onGiveToken: (_, {atOnce = false}) async {
          connections.hostProgress = const HostProgress();
          return null;
        },
      );
      expect(find.textContaining('makes your account once it has read the organization'), findsOneWidget);
      await pressOrganizationAction(tester, 'giveToken');
      expect(connections.asked, contains('connect build'));
      expect(_action('giveToken'), findsNothing);
    });

    // Harm: a machine just prepared from this window never admits anyone, and its page, not connected to it, says
    // nothing of the token it waits for, so the person waits for an admission that never comes.
    testWidgets('a machine last heard waiting for its token says so while not connected, and takes it there', (
      tester,
    ) async {
      final connections = FixtureConnections()..hearTokenWait('build', waits: true);
      final gave = <String>[];
      await page(
        tester,
        'hana',
        connections: connections,
        onGiveToken: (host, {atOnce = false}) async {
          gave.add(host);
          // As the token's step does once the machine took it.
          connections.hearTokenWait(host, waits: false);
          return null;
        },
      );
      expect(_action('giveToken'), findsOneWidget);
      expect(find.byKey(const ValueKey('organization.tokenWaitHeard')), findsOneWidget);
      await pressOrganizationAction(tester, 'giveToken');
      expect(gave, ['build']);
      expect(_action('giveToken'), findsNothing, reason: 'it took the token');
      expect(find.byKey(const ValueKey('organization.tokenWaitHeard')), findsNothing);
    });

    // Harm: the page's own read of the machine fails, as when its status cannot be run there, and the token the last
    // Connect heard it wait for goes unsaid, so the machine never admits anyone.
    testWidgets('a wait the last Connect heard is said and offered while the page cannot read the machine', (
      tester,
    ) async {
      final connections = FixtureConnections(['build'])
        ..waiting.add('build')
        ..refuseNext = const OrganizationRefused('build could not say how far it has come.');
      await page(tester, 'hana', connections: connections, onGiveToken: (_, {atOnce = false}) async => null);
      expect(find.text('build could not say how far it has come.'), findsOneWidget, reason: 'its read was refused');
      expect(_action('giveToken'), findsOneWidget);
    });

    // Harm: a wait the page read itself goes unsaid once the connection is let go, and the person is told only to
    // connect to a machine that admits nobody before its token.
    testWidgets("a wait the page's own read heard is still said and offered after a disconnect", (tester) async {
      final connections = FixtureConnections(['build'])..hostProgress = const HostProgress(waitsForToken: true);
      await page(tester, 'hana', connections: connections, onGiveToken: (_, {atOnce = false}) async => null);
      expect(_action('giveToken'), findsOneWidget);
      await connections.disconnect('build');
      await tester.pumpAndSettle();
      expect(_action('giveToken'), findsOneWidget, reason: 'not connected, it still waits');
      expect(find.byKey(const ValueKey('organization.tokenWaitHeard')), findsOneWidget);
    });

    // Harm: the machine took the token, the read that would say so failed, and the page goes on offering the token.
    testWidgets('a token taken ends the wait the page read, though the read after it fails', (tester) async {
      final connections = _Unreadable(['build'])..hostProgress = const HostProgress(waitsForToken: true);
      await page(
        tester,
        'hana',
        connections: connections,
        onGiveToken: (host, {atOnce = false}) async {
          // As the token's step does once the machine took it; the machine cannot be read after.
          connections.unreadable = true;
          connections.hearTokenWait(host, waits: false);
          return null;
        },
      );
      await pressOrganizationAction(tester, 'giveToken');
      expect(connections.asked, contains('progress build'), reason: 'read after, and refused');
      expect(_action('giveToken'), findsNothing);
    });

    // Harm: the token is given from a page whose machine was never read, and the connection it now admits is never
    // made.
    testWidgets('a token given where the wait was heard elsewhere connects after, though the read fails', (
      tester,
    ) async {
      final connections = FixtureConnections()..hearTokenWait('build', waits: true);
      await page(
        tester,
        'hana',
        connections: connections,
        onGiveToken: (host, {atOnce = false}) async {
          connections.hearTokenWait(host, waits: false);
          connections.refuseNext = const OrganizationRefused('build could not say how far it has come.');
          return null;
        },
      );
      await pressOrganizationAction(tester, 'giveToken');
      expect(connections.asked, contains('connect build'));
    });

    // Harm: why no token was given stands at the page's head, far from the button that asked, and the button's own
    // answer is lost.
    testWidgets('a press that gives no token where the wait was heard elsewhere says why beside it, once', (
      tester,
    ) async {
      final connections = FixtureConnections()..hearTokenWait('build', waits: true);
      await page(
        tester,
        'hana',
        connections: connections,
        onGiveToken: (_, {atOnce = false}) async {
          // As a machine not connected to is: its read after the press is refused.
          connections.refuseNext = const OrganizationRefused('Connect to build first.');
          return 'No GitHub token is kept on this computer.';
        },
      );
      await pressOrganizationAction(tester, 'giveToken');
      expect(find.text('No GitHub token is kept on this computer.'), findsOneWidget);
      expect(_action('giveToken'), findsOneWidget, reason: 'it still waits');
      expect(find.byKey(const ValueKey('organization.tokenWhy')), findsOneWidget, reason: 'beside the button');
    });

    // Harm: the page says the connection is down and offers Connect, while the machine waits for a token no Connect
    // can stand in for.
    testWidgets('a connection not up while the wait was heard elsewhere is not called down', (tester) async {
      final connections = _DownConnections(['build'])
        ..hearTokenWait('build', waits: true)
        ..refuseNext = const OrganizationRefused('build could not say how far it has come.');
      await page(tester, 'hana', connections: connections);
      final said = tester.widget<Text>(find.byKey(const ValueKey('organization.connectionWords'))).data!;
      expect(said, isNot(contains('is down')));
    });

    // Harm: a machine of the same name at another address is said to wait for a token, and offered one, because the
    // machine before it did.
    testWidgets('a wait the page read is no word of a machine moved to another address since', (tester) async {
      final connections = _Moving(['build'])..hostProgress = const HostProgress(waitsForToken: true);
      final made = await page(
        tester,
        'hana',
        connections: connections,
        onGiveToken: (_, {atOnce = false}) async => null,
      );
      expect(_action('giveToken'), findsOneWidget);
      // As Porelo's own connections do: one written for the old address is none to the new one.
      await connections.disconnect('build');
      connections.machine = 'at 203.0.113.99';
      made.source.view = organizationFor(
        'hana',
        host: OrganizationHost(
          name: 'build',
          address: '203.0.113.99',
          port: buildHost.port,
          hostKey: buildHost.hostKey,
          admins: const ['hana'],
          projects: const ['demo'],
        ),
      );
      await tester.widget<OrganizationHostPage>(find.byType(OrganizationHostPage)).organization.refresh();
      await tester.pumpAndSettle();
      expect(_action('giveToken'), findsNothing);
    });

    // Harm: someone who is not the machine's Machine Admin reads on its page that it waits for their token.
    testWidgets('a wait heard is said to the Machine Admin alone', (tester) async {
      final connections = FixtureConnections(['build'])..hearTokenWait('build', waits: true);
      await page(tester, 'mia', connections: connections);
      expect(find.text('Waiting for its token'), findsNothing);
    });

    // Harm: a read on its way when the Machine Admin role was taken shows its answer anyway, and keeps a member from
    // their project by a wait nobody may read to them now.
    testWidgets('a read answered after the Machine Admin role was taken is not shown', (tester) async {
      final connections = _Held(['build'])
        ..hostProgress = HostProgress.read('{"projects":[{"project":"demo","state":"waiting-for-token"}]}');
      final hold = connections.hold = Completer<void>();
      final made = await page(
        tester,
        'mia',
        connections: connections,
        shown: const OrganizationHost(name: 'build', admins: ['mia'], projects: ['demo']),
      );
      made.source.view = organizationFor('mia');
      await tester.widget<OrganizationHostPage>(find.byType(OrganizationHostPage)).organization.refresh();
      await tester.pumpAndSettle();
      hold.complete();
      await tester.pumpAndSettle();
      final said = tester.widget<Text>(find.byKey(const ValueKey('organization.connectionWords'))).data!;
      expect(said, contains('Ready to work on: demo'));
    });

    // Harm: the token's step and the page each ask the machine as root once it took the token, two logins its host
    // counts, and a refusal of the page's own read stands at its head while the token's dialog is open.
    testWidgets("a token given from the page has the machine asked once, by the token's step", (tester) async {
      final connections = FixtureConnections(['build'])..hostProgress = const HostProgress(waitsForToken: true);
      await page(
        tester,
        'hana',
        connections: connections,
        onGiveToken: (host, {atOnce = false}) async {
          connections.hostProgress = const HostProgress();
          // As the token's step does once the machine took it.
          connections.hearTokenWait(host, waits: false);
          await connections.progress(host);
          return null;
        },
      );
      connections.asked.clear();
      await pressOrganizationAction(tester, 'giveToken');
      expect(connections.asked.where((each) => each.startsWith('progress')), ['progress build']);
      expect(_action('giveToken'), findsNothing, reason: 'it no longer waits');
    });

    // Harm: the machine took the token and could not be read after; the connection comes up, and nothing says why the
    // page shows nothing the machine said.
    testWidgets('a read refused after the token was given is said, though the connection comes up after', (
      tester,
    ) async {
      final connections = _Unreadable(['build'])..hostProgress = const HostProgress(waitsForToken: true);
      await page(
        tester,
        'hana',
        connections: connections,
        onGiveToken: (host, {atOnce = false}) async {
          connections.unreadable = true;
          connections.hearTokenWait(host, waits: false);
          return null;
        },
      );
      await pressOrganizationAction(tester, 'giveToken');
      expect(connections.asked, contains('connect build'));
      expect(find.text('build could not say how far it has come.'), findsOneWidget);
    });

    // Harm: the connection went while a project's token was given, the button goes with it, and why no token was
    // given is said nowhere.
    testWidgets("why a project's token was not given is said once the connection went", (tester) async {
      final connections = FixtureConnections(['build'])
        ..hostProgress = HostProgress.read('{"projects":[{"project":"demo","state":"waiting-for-token"}]}');
      await page(
        tester,
        'hana',
        connections: connections,
        onGiveToken: (host, {atOnce = false}) async {
          await connections.disconnect(host);
          return 'No GitHub token is kept on this computer.';
        },
      );
      await pressOrganizationAction(tester, 'giveToken');
      expect(find.text('No GitHub token is kept on this computer.'), findsOneWidget);
    });

    /// Asks each machine once on every change of [connections], as the window does for every machine its Machine Admin
    /// may ask.
    void asksOnce(WidgetTester tester, FixtureConnections connections) {
      final organization = tester.widget<OrganizationHostPage>(find.byType(OrganizationHostPage)).organization;
      void askOnce() => connections.askOnce(organization.view!);
      connections.addListener(askOnce);
      addTearDown(() => connections.removeListener(askOnce));
      askOnce();
    }

    Iterable<String> reads(FixtureConnections connections) =>
        connections.asked.where((each) => each.startsWith('progress'));

    // Harm: once the machine took the token, the window's own ask of each machine and the token's step each log in as
    // root, two logins its host counts.
    testWidgets("a token given from the page has the machine asked once, with the window's asks listening", (
      tester,
    ) async {
      final connections = FixtureConnections(['build'])..hostProgress = const HostProgress(waitsForToken: true);
      await page(
        tester,
        'hana',
        connections: connections,
        onGiveToken: (host, {atOnce = false}) async {
          connections.hostProgress = const HostProgress();
          await connections.tokenTaken(host);
          return null;
        },
      );
      asksOnce(tester, connections);
      await tester.pumpAndSettle();
      connections.asked.clear();
      await pressOrganizationAction(tester, 'giveToken');
      expect(reads(connections), ['progress build']);
      expect(_action('giveToken'), findsNothing, reason: 'it no longer waits');
    });

    // Harm: a token given from the machine's row while its page is open has the page, the window and the token's step
    // each log in as root.
    testWidgets('a token given elsewhere has the machine asked once while its page is open', (tester) async {
      final connections = FixtureConnections(['build'])..hostProgress = const HostProgress(waitsForToken: true);
      await page(tester, 'hana', connections: connections);
      asksOnce(tester, connections);
      await tester.pumpAndSettle();
      connections.asked.clear();
      connections.hostProgress = const HostProgress();
      await connections.tokenTaken('build');
      await tester.pumpAndSettle();
      expect(reads(connections), ['progress build']);
      expect(_action('giveToken'), findsNothing);
    });

    // Harm: the token's step connects first, and the page logs in as root beside it while the token's dialog is open.
    testWidgets('a token given where the page was not connected has the machine asked once', (tester) async {
      final connections = FixtureConnections()..hearTokenWait('build', waits: true);
      await page(
        tester,
        'hana',
        connections: connections,
        onGiveToken: (host, {atOnce = false}) async {
          // As the token's step does: it connects first.
          await connections.connect(host);
          await connections.tokenTaken(host);
          return null;
        },
      );
      await pressOrganizationAction(tester, 'giveToken');
      expect(reads(connections), ['progress build']);
    });

    // Harm: why a project's token was not given, asked from the project's row, is said nowhere.
    testWidgets("why a project's token was not given from its row is said", (tester) async {
      final connections = FixtureConnections(['build'])
        ..hostProgress = HostProgress.read('{"projects":[{"project":"demo","state":"waiting-for-token"}]}');
      await page(
        tester,
        'hana',
        connections: connections,
        onGiveToken: (_, {atOnce = false}) async => 'No GitHub token is kept on this computer.',
      );
      final menus = tester.widgetList<CommandMenu>(find.byType(CommandMenu));
      menus.expand((menu) => menu.commands).singleWhere((command) => command.id == 'giveToken/build/demo').run();
      await tester.pumpAndSettle();
      expect(find.text('No GitHub token is kept on this computer.'), findsOneWidget);
    });

    // Harm: the page could not read the machine, its wait then ends elsewhere, and the page never reads it again.
    testWidgets('a wait that ends elsewhere has the page read the machine it could not read before', (tester) async {
      final connections = FixtureConnections(['build'])
        ..waiting.add('build')
        ..refuseNext = const OrganizationRefused('build could not say how far it has come.');
      await page(tester, 'hana', connections: connections);
      connections.asked.clear();
      connections.hearTokenWait('build', waits: false);
      await tester.pumpAndSettle();
      expect(reads(connections), ['progress build']);
    });

    // Harm: a press that gave no token logs in as root all the same.
    testWidgets('a press that gives no token asks the machine nothing', (tester) async {
      final connections = FixtureConnections(['build'])..hostProgress = const HostProgress(waitsForToken: true);
      await page(
        tester,
        'hana',
        connections: connections,
        onGiveToken: (_, {atOnce = false}) async => 'No GitHub token is kept on this computer.',
      );
      connections.asked.clear();
      await pressOrganizationAction(tester, 'giveToken');
      expect(reads(connections), isEmpty);
      expect(find.text('No GitHub token is kept on this computer.'), findsOneWidget);
    });

    // Harm: after the token the page asks a machine it is not connected to, which refuses it, and once the connection
    // comes up it never reads the machine.
    testWidgets('a token given where the page was not connected reads the machine once, connected after', (
      tester,
    ) async {
      final connections = _Strict()..hearTokenWait('build', waits: true);
      await page(
        tester,
        'hana',
        connections: connections,
        onGiveToken: (host, {atOnce = false}) async {
          // As the token's step does once the machine took it.
          await connections.tokenTaken(host);
          return null;
        },
      );
      await pressOrganizationAction(tester, 'giveToken');
      expect(connections.asked, contains('connect build'));
      expect(reads(connections), ['progress build']);
    });

    // Harm: a read on its way when the machine moved to another address shows the old machine's wait as the new one's.
    testWidgets("a read answered after the machine moved is not the moved machine's word", (tester) async {
      final connections = _HeldMoving(['build'])..hostProgress = const HostProgress(waitsForToken: true);
      final hold = connections.hold = Completer<void>();
      final made = await page(
        tester,
        'hana',
        connections: connections,
        onGiveToken: (_, {atOnce = false}) async => null,
      );
      await connections.disconnect('build');
      connections.machine = 'at 203.0.113.99';
      made.source.view = organizationFor(
        'hana',
        host: OrganizationHost(
          name: 'build',
          address: '203.0.113.99',
          port: buildHost.port,
          hostKey: buildHost.hostKey,
          admins: const ['hana'],
          projects: const ['demo'],
        ),
      );
      await tester.widget<OrganizationHostPage>(find.byType(OrganizationHostPage)).organization.refresh();
      await tester.pumpAndSettle();
      hold.complete();
      await tester.pumpAndSettle();
      expect(_action('giveToken'), findsNothing);
    });

    // Harm: the read after the token is refused, the page logs in as root a second time, and a second read that
    // passes hides why the first could not say how the machine stands.
    testWidgets("a read refused after the token was taken is said, and the machine is not asked again", (tester) async {
      final connections = _Unreadable(['build'])..hostProgress = const HostProgress(waitsForToken: true);
      await page(
        tester,
        'hana',
        connections: connections,
        onGiveToken: (host, {atOnce = false}) async {
          connections.unreadable = true;
          // As the token's step does once the machine took it; it says nothing of a read refused after.
          try {
            await connections.tokenTaken(host);
          } on OrganizationRefused {
            // Said by the page.
          }
          connections.unreadable = false;
          return null;
        },
      );
      asksOnce(tester, connections);
      await tester.pumpAndSettle();
      connections.asked.clear();
      await pressOrganizationAction(tester, 'giveToken');
      expect(reads(connections), ['progress build']);
      expect(find.text('build could not say how far it has come.'), findsOneWidget);
    });

    // Harm: the token's step connected the machine, no token was given, and the page never reads the machine it is
    // now connected to.
    testWidgets('a press that gave no token reads the machine the step connected meanwhile', (tester) async {
      final connections = FixtureConnections()..hearTokenWait('build', waits: true);
      await page(
        tester,
        'hana',
        connections: connections,
        onGiveToken: (host, {atOnce = false}) async {
          // As the token's step does: it connects first.
          await connections.connect(host);
          return 'No GitHub token is kept on this computer.';
        },
      );
      await pressOrganizationAction(tester, 'giveToken');
      expect(reads(connections), ['progress build']);
    });

    // Harm: the Machine Admin role was taken while the read after the token was on its way, and its refusal is said
    // at the page's head to someone who may no longer read the machine.
    testWidgets('a read refused after the role was taken meanwhile is not said', (tester) async {
      final connections = _Held(['build'])..hostProgress = const HostProgress(waitsForToken: true);
      final made = await page(
        tester,
        'hana',
        connections: connections,
        onGiveToken: (_, {atOnce = false}) async => null,
      );
      final hold = connections.hold = Completer<void>();
      await pressOrganizationAction(tester, 'giveToken', settle: () => tester.pump());
      made.source.view = organizationFor(
        'hana',
        host: const OrganizationHost(name: 'build', admins: ['mia'], projects: ['demo']),
      );
      await tester.widget<OrganizationHostPage>(find.byType(OrganizationHostPage)).organization.refresh();
      await tester.pump();
      connections.refuseNext = const OrganizationRefused('build could not say how far it has come.');
      hold.complete();
      await tester.pumpAndSettle();
      expect(find.text('build could not say how far it has come.'), findsNothing);
    });

    // Harm: the machine moved while the page's read of the old one was on its way, and the new one is never read.
    testWidgets('a machine moved while its read was on its way is read anew', (tester) async {
      final connections = _HeldMoving(['build'])..hostProgress = const HostProgress(waitsForToken: true);
      final hold = connections.hold = Completer<void>();
      final made = await page(tester, 'hana', connections: connections);
      connections
        ..hold = null
        ..machine = 'at 203.0.113.99';
      made.source.view = organizationFor(
        'hana',
        host: OrganizationHost(
          name: 'build',
          address: '203.0.113.99',
          port: buildHost.port,
          hostKey: buildHost.hostKey,
          admins: const ['hana'],
          projects: const ['demo'],
        ),
      );
      await tester.widget<OrganizationHostPage>(find.byType(OrganizationHostPage)).organization.refresh();
      await tester.pumpAndSettle();
      hold.complete();
      await tester.pumpAndSettle();
      expect(reads(connections), ['progress build', 'progress build'], reason: 'the old machine, then the new one');
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

    // Harm: a person who changed the organization waits up to five minutes for the machine's next round, or the page
    // keeps saying what the machine said before its read.
    testWidgets('Read the organization now shows what the read brought, at once', (tester) async {
      final connections = FixtureConnections(['build'])
        ..hostProgress = const HostProgress(
          projects: [
            HostProjectProgress(project: 'retired', state: 'held', why: 'app and docs have unpushed commits'),
            HostProjectProgress(project: 'pending', state: 'carried'),
          ],
        )
        ..afterFollow = const HostProgress(
          projects: [HostProjectProgress(project: 'pending', state: 'carried')],
        );
      await page(tester, 'hana', connections: connections);
      expect(find.text('retired'), findsOneWidget);
      await pressOrganizationAction(tester, 'readNow/build');
      expect(connections.asked, containsAllInOrder(['followNow build', 'progress build']));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('organization.readNowWhy'))).data,
        'build read the organization.',
      );
      expect(find.text('retired'), findsNothing, reason: 'the state after the read, without a wait');
    });

    // Harm: a machine without the start is asked to run it anyway, or the person cannot tell why it is not offered.
    testWidgets('a machine without the start greys Read the organization now with its reason and runs nothing', (
      tester,
    ) async {
      const why = "build's Porelo offers no start of its read of the organization";
      final connections = FixtureConnections(['build'])..noFollowNow = why;
      await page(tester, 'mia', connections: connections);
      final button = find.byKey(const ValueKey('organization.readNow/build'));
      await tester.ensureVisible(button);
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('organization.noReadNowWhy'))).data,
        'Read the organization now: $why',
      );
      await tester.tap(button, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(connections.asked, isNot(contains('followNow build')));
    });

    // Harm: a machine that turns out to offer no start says its reason twice, or keeps a stale answer beside it.
    testWidgets('a machine that answers it offers no start says so once, greyed', (tester) async {
      const why = 'porelo: host follow is unavailable; update the host program to one supporting org follow-now';
      final connections = FixtureConnections(['build'])..followUnavailable = why;
      await page(tester, 'mia', connections: connections);
      await pressOrganizationAction(tester, 'readNow/build');
      expect(connections.asked, contains('followNow build'));
      final button = find.byKey(const ValueKey('organization.readNow/build'));
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      expect(find.byKey(const ValueKey('organization.readNowWhy')), findsNothing);
      expect(find.textContaining(why), findsOneWidget);
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

/// Connections to a machine that, once [unreadable], refuses every read of how far it has come.
class _Unreadable extends FixtureConnections {
  _Unreadable(super.hosts);

  bool unreadable = false;

  @override
  Future<HostProgress> progress(String host) async {
    if (!unreadable) return super.progress(host);
    asked.add('progress $host');
    // A machine answers over ssh, never within the call that asked it.
    await Future<void>.value();
    throw OrganizationRefused('$host could not say how far it has come.');
  }
}

/// Connections that say which machine the organization names build, as Porelo's own do, as [machine].
class _Moving extends FixtureConnections {
  _Moving(super.hosts);

  Object? machine = 'at 203.0.113.7';

  @override
  Object? machineOf(String host) => machine;
}

/// Connections whose reads of how far a machine has come wait for [hold] before they answer.
class _Held extends FixtureConnections {
  _Held(super.hosts);

  Completer<void>? hold;

  @override
  Future<HostProgress> progress(String host) async {
    await hold?.future;
    return super.progress(host);
  }
}

/// Held reads of a machine that says which machine it is, as [_Moving] does.
class _HeldMoving extends _Held {
  _HeldMoving(super.hosts);

  Object? machine = 'at 203.0.113.7';

  @override
  Object? machineOf(String host) => machine;
}

/// Connections that refuse a read of a machine not connected to, as Porelo's own do.
class _Strict extends FixtureConnections {
  _Strict();

  @override
  Future<HostProgress> progress(String host) async {
    if (connected(host)) return super.progress(host);
    asked.add('progress $host, not connected');
    // A machine answers over ssh, never within the call that asked it.
    await Future<void>.value();
    throw OrganizationRefused('Connect to $host first.');
  }
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

/// A connected forge whose forward answers as told, and is raised anew on request.
class _DeadForge extends _ForgeConnections {
  _DeadForge({required this.answers}) : super(connected: true);

  bool answers;
  bool heals = true;
  bool refuseRaise = false;
  bool failOtherwise = false;
  final raised = <String>[];
  final order = <String>[];

  @override
  Future<bool?> forgeAnswers(String host) async => answers;

  @override
  Future<void> raiseForwardAnew(String host) async {
    raised.add(host);
    order.add('raise');
    if (refuseRaise) throw const OrganizationRefused('ssh said no');
    if (failOtherwise) throw StateError('the stand-in broke');
    answers = heals;
    notifyListeners();
  }
}
