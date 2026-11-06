import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/host_progress.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/ui/filtered_list_section.dart';
import 'package:porelo_frontend/src/ui/organization_dialogs.dart';
import 'package:porelo_frontend/src/ui/organization_page.dart';
import 'package:porelo_frontend/src/ui/tokens.dart';
import 'package:porelo_frontend/src/ui/shell_rail.dart';

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';
import 'organization_actions.dart';

Finder _action(String id) => organizationAction(id);

class _Opened {
  String? project;
  String? host;
}

Future<(FixtureOrganization, Organization, _Opened)> _pump(
  WidgetTester tester,
  String me, {
  List<OrganizationKey> keys = const [],
  OrganizationView? view,
  Size size = const Size(1400, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fixture = FixtureOrganization(view ?? organizationFor(me), keys: keys);
  final organization = Organization(fixture);
  addTearDown(organization.dispose);
  final opened = _Opened();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OrganizationPage(
          settings: Settings(MemorySettingsStore()),
          organization: organization,
          onProject: (name) => opened.project = name,
          onHost: (name) => opened.host = name,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (fixture, organization, opened);
}

Future<void> _open(WidgetTester tester, Finder action) async {
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, Key field, String choice) async {
  await tester.tap(find.byKey(field));
  await tester.pumpAndSettle();
  await tester.tap(find.text(choice).last);
  await tester.pumpAndSettle();
}

class _Checking extends FixtureOrganization implements FoundingChecks {
  _Checking(super.view);

  final asked = <String>[];
  OrganizationRefused? refuseCheck;
  Future<void>? hold;
  bool failCheck = false;

  @override
  Future<List<FoundingNeed>> checkFounding(String address, {bool replace = false}) async {
    asked.add(address);
    await hold;
    if (failCheck) throw const FormatException('broken');
    if (refuseCheck case final refused?) throw refused;
    return const [
      FoundingNeed(name: 'this-machine', state: 'ready', words: 'This machine is ready.'),
      FoundingNeed(
        name: 'key-listed',
        state: 'missing',
        words: 'The key is not listed.',
        next: 'List it on the forge.',
      ),
    ];
  }
}

void main() {
  // Harm: the organization cannot be found, or the rail's place of a page that is one of its own is lost.
  // Harm: a person presses Refresh and goes on reading an organization that has moved on, a card filed or a
  // project added elsewhere, until some later write of theirs is refused.
  testWidgets('Refresh in the rail reads the organization again', (tester) async {
    await World.startBackend(World.work);
    final fixture = FixtureOrganization(organizationFor('mia'));
    await World.startApp(tester, organizationSource: fixture);
    await tester.tap(find.byKey(const ValueKey('rail organization')));
    await World.settle(tester);
    expect(find.text('aaron'), findsNothing);
    final read = organizationFor('mia');
    fixture.view = organizationFor(
      'mia',
      persons: [
        const OrganizationPerson(login: 'aaron', key: 'SHA256:aaron', standing: CardStanding.trusted),
        ...read.persons,
      ],
    );
    await tester.tap(find.byKey(const Key('refresh-all')));
    await World.settle(tester);
    expect(find.text('aaron'), findsOneWidget);
  });

  // Harm: a person cannot get from the organization to a project of theirs, or back to their list.
  // Harm: `default` and a project registered on this machine alone are out of reach once an organization is read.
  testWidgets('with an organization, the projects outside it are a step away, and back', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester, organizationSource: FixtureOrganization(organizationFor('mia')));
    await tester.tap(find.byKey(const ValueKey('rail projects')));
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('projects-of-machines')));
    await World.settle(tester);
    expect(find.byKey(const ValueKey('my-project demo')), findsNothing);
    await tester.tap(find.byKey(const Key('projects-of-organization')));
    await World.settle(tester);
    expect(find.byKey(const ValueKey('my-project demo')), findsOneWidget);
  });

  // Harm: in the foo test a project stood under My projects with its repository unmade and nothing said so:
  // "Open under Projects" named a place in the side bar while *Open the project* made a repository.
  group('a project with no Git repository yet', () {
    const fresh = OrganizationProject(name: 'fresh', admins: ['pat'], opened: false);

    testWidgets('its Project Admin creates it on its row, once the review is chosen', (tester) async {
      final (fixture, _, _) = await _pump(tester, 'pat', view: organizationFor('pat', moreProjects: const [fresh]));
      fixture.projects = {
        'fresh': const ProjectView(name: 'fresh', revision: 'p9', roles: ['admin'], repositories: [], members: []),
      };
      expect(find.text('fresh has no Git repository yet.'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('organization.createRepository fresh')));
      await tester.tap(find.byKey(const ValueKey('organization.createRepository fresh')));
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('organization-confirm'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull, reason: 'Nobody has said about review yet.');
      await tester.tap(find.byKey(const Key('organization-review-optional')));
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(fixture.writes.single.change, OrganizationChange.createProjectRepository);
      expect(fixture.writes.single.input, {'project': 'fresh', 'review': 'optional'});
      expect(fixture.writes.single.base, 'p9');
    });

    // Harm: a stale read says a repository is missing, and a person creates what is there.
    testWidgets('a stale organization does not say it has none', (tester) async {
      await _pump(tester, 'pat', view: organizationFor('pat', moreProjects: const [fresh], stale: true));
      expect(find.textContaining('no Git repository yet'), findsNothing);
      expect(find.byKey(const ValueKey('organization.createRepository fresh')), findsNothing);
    });

    testWidgets('anyone else reads who it waits for, with nothing to press', (tester) async {
      await _pump(tester, 'mia', view: organizationFor('mia', moreProjects: const [fresh]));
      expect(find.text('fresh has no Git repository yet. It waits for pat.'), findsOneWidget);
      expect(find.byKey(const ValueKey('organization.createRepository fresh')), findsNothing);
    });

    testWidgets('offers neither a way to it nor to fill it, and an older Porelo that says nothing reads as before', (
      tester,
    ) async {
      await _pump(
        tester,
        'pat',
        view: organizationFor(
          'pat',
          moreProjects: const [
            fresh,
            OrganizationProject(name: 'older', admins: ['pat']),
          ],
        ),
      );
      expect(_action('goToProject/fresh'), findsNothing);
      expect(_action('initializeProject/fresh'), findsNothing);
      expect(_action('goToProject/older'), findsOneWidget);
      expect(find.text('older has no Git repository yet.'), findsNothing);
    });

    testWidgets('someone naming themselves makes it in one step with the review choice', (tester) async {
      final (fixture, _, _) = await _pump(tester, 'olive');
      await pressOrganizationAction(tester, 'addProject');
      await tester.enterText(find.byKey(const Key('organization-name')), 'mine');
      await tester.tap(find.byKey(const Key('organization-person')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('olive (you)').last);
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('organization-confirm'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.tap(find.byKey(const Key('organization-review-required')));
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(fixture.writes.single.input, {'project': 'mine', 'admin': 'olive', 'review': 'required'});
    });

    testWidgets('someone naming another only adds it, as that person makes it', (tester) async {
      final (fixture, _, _) = await _pump(tester, 'olive');
      await pressOrganizationAction(tester, 'addProject');
      await tester.enterText(find.byKey(const Key('organization-name')), 'theirs');
      await tester.tap(find.byKey(const Key('organization-person')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('pat').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('organization-review-required')), findsNothing);
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.input, {'project': 'theirs', 'admin': 'pat'});
    });

    // Harm: nothing tells a Project Admin named by someone else, so the project just stands there.
    Future<FixtureOrganization> needsYouOf(WidgetTester tester, String me) async {
      final source = FixtureOrganization(organizationFor(me, moreProjects: const [fresh]));
      await World.startBackend(World.work);
      await World.startApp(tester, organizationSource: source);
      // Straight there: this may be the first page anyone looks at.
      await tester.tap(find.byKey(const ValueKey('rail attention')));
      await World.settle(tester);
      return source;
    }

    testWidgets('has a row under Needs you for its named Project Admin, until it exists', (tester) async {
      final source = await needsYouOf(tester, 'pat');
      expect(find.text('fresh has no Git repository yet'), findsOneWidget);
      await tester.tap(find.text("Create the project's Git repository"));
      await World.settle(tester);
      expect(find.text('Create the Git repository of fresh?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await World.settle(tester);

      source.view = organizationFor(
        'pat',
        moreProjects: const [
          OrganizationProject(name: 'fresh', admins: ['pat'], opened: true),
        ],
      );
      await tester.tap(find.byKey(const ValueKey('rail organization')));
      await World.settle(tester);
      await tester.tap(find.byKey(const ValueKey('rail attention')));
      await World.settle(tester);
      expect(find.text('fresh has no Git repository yet'), findsNothing);
    });

    testWidgets('has none for an Organization Admin who is not its Project Admin', (tester) async {
      await needsYouOf(tester, 'olive');
      expect(find.text('fresh has no Git repository yet'), findsNothing);
    });
  });

  // Harm: in the foo test nothing said anything at creating, and later *Prepare a machine…* was simply grey.
  testWidgets('a list says why a command is grey, in words and with no hover', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FilteredListSection(
            title: 'Machines',
            storageId: 'grey',
            commands: [
              Command(
                id: 'grey',
                label: 'Prepare a machine…',
                group: 'Machines',
                run: () {},
                unavailable: 'it stands at https',
              ),
              Command(id: 'open', label: 'Add a machine…', group: 'Machines', run: () {}),
            ],
            rows: const [],
          ),
        ),
      ),
    );
    expect(find.text('Prepare a machine: it stands at https'), findsOneWidget);
    expect(find.textContaining('Add a machine:'), findsNothing);
  });

  // Harm: a grey *Add* with nothing to say why, on a list that goes through a page's pending changes.
  testWidgets('a button a list draws itself says why too, through pending changes', (tester) async {
    final held = Organization(FixtureOrganization(organizationFor('hana')));
    addTearDown(held.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const FilteredListSection(
            title: 'Members',
            storageId: 'grey',
            greyWords: ['Add: nobody is left'],
            rows: [],
          ).withOrganizationChanges(held, names: const []),
        ),
      ),
    );
    expect(find.text('Add: nobody is left'), findsOneWidget);
  });

  // Harm: a machine named and not yet prepared offers a page that goes on leaving, and *Change address
  // and key…*, the wrong thing to press first for a machine still to be rented.
  group('a machine with no address yet', () {
    testWidgets('says so, and its Machine Admin prepares it with its name filled in', (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final organization = Organization(FixtureOrganization(organizationFor('olive')));
      addTearDown(organization.dispose);
      String? prepared;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrganizationPage(organization: organization, onHost: (_) {}, onPrepare: (host) => prepared = host),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('spare has no address yet.'), findsOneWidget);
      expect(_action('openHost/spare'), findsNothing);
      expect(_action('enterHost/spare'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('organization.prepare/spare')));
      await tester.tap(find.byKey(const ValueKey('organization.prepare/spare')));
      expect(prepared, 'spare');
    });

    testWidgets('anyone else reads who it waits for, with nothing to press', (tester) async {
      await _pump(tester, 'hana');
      expect(find.textContaining('spare has no address yet. It waits for olive.'), findsOneWidget);
      expect(find.byKey(const ValueKey('organization.prepare/spare')), findsNothing);
      expect(_action('enterHost/spare'), findsNothing);
    });

    testWidgets('one with an address says Go to the machine', (tester) async {
      await _pump(tester, 'hana');
      expect(_action('openHost/build'), findsOneWidget);
      expect(_action('enterHost/build'), findsNothing);
    });
  });

  // Harm: in the foo test a machine waited for its token with nothing under Needs you, so only someone
  // who opened its page by chance found out what it waited for.
  group('a machine that waits for its first token', () {
    FixtureConnections waiting() => FixtureConnections(['build'])
      ..waiting.add('build')
      ..hostProgress = const HostProgress(waitsForToken: true);

    Future<void> open(WidgetTester tester, String me, FixtureConnections connections) async {
      await World.startBackend(World.work);
      await World.startApp(
        tester,
        organizationSource: FixtureOrganization(organizationFor(me)),
        hostConnections: connections,
      );
      // The organization is read when its page opens, which a *Connect* comes from.
      await tester.tap(find.byKey(const ValueKey('rail organization')));
      await World.settle(tester);
      await tester.tap(find.byKey(const ValueKey('rail attention')));
      await World.settle(tester);
    }

    testWidgets('has a row for its Machine Admin, which leads to the token and goes once it is given', (tester) async {
      final connections = waiting();
      await open(tester, 'hana', connections);
      expect(find.textContaining('build waits for your token'), findsOneWidget);
      await tester.tap(find.text('Go to its token'));
      await World.settle(tester);
      expect(find.byKey(const ValueKey('organization.giveToken')), findsOneWidget);

      connections.waiting.clear();
      connections.hostProgress = const HostProgress(waitsForToken: false);
      connections.notifyListeners();
      await tester.tap(find.byKey(const ValueKey('rail attention')));
      await World.settle(tester);
      expect(find.textContaining('build waits for your token'), findsNothing);
    });

    // Harm: a row leading to a page that offers a revoked person no button, in place of the row that says
    // the machine cannot be reached.
    testWidgets('has none for a Machine Admin whose card is revoked', (tester) async {
      await World.startBackend(World.work);
      await World.startApp(
        tester,
        organizationSource: FixtureOrganization(
          organizationFor(
            'hana',
            persons: const [OrganizationPerson(login: 'hana', key: 'SHA256:hana', standing: CardStanding.revoked)],
          ),
        ),
        hostConnections: waiting(),
      );
      await tester.tap(find.byKey(const ValueKey('rail organization')));
      await World.settle(tester);
      await tester.tap(find.byKey(const ValueKey('rail attention')));
      await World.settle(tester);
      expect(find.textContaining('build waits for your token'), findsNothing);
    });

    testWidgets('has none for someone who cannot give it', (tester) async {
      await open(tester, 'mia', waiting());
      expect(find.textContaining('build waits for your token'), findsNothing);
    });
  });

  // Harm: a person finds their hosts nowhere, or cannot come back from one.
  testWidgets('with an organization, Organization lists its machines, and opens one\'s page', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(
      tester,
      organizationSource: FixtureOrganization(organizationFor('mia')),
      hostConnections: FixtureConnections(),
    );
    await tester.tap(find.byKey(const ValueKey('rail organization')));
    await World.settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('my-host build')),
      200,
      scrollable: find
          .descendant(of: find.byKey(const Key('organization-page')), matching: find.byType(Scrollable))
          .first,
    );
    expect(find.byKey(const ValueKey('my-host build')), findsOneWidget);
    expect(find.text('My machines'), findsWidgets);
    await tester.ensureVisible(find.byKey(const ValueKey('my-host build')));
    await World.settle(tester);
    await tester.tap(find.byKey(const ValueKey('my-host build')));
    await World.settle(tester);
    expect(find.byKey(const ValueKey('organization-host build')), findsOneWidget);
    await tester.tap(find.byKey(const Key('organization-host-back')));
    await World.settle(tester);
    expect(find.byKey(const Key('organization-page')), findsOneWidget);
  });

  testWidgets('with an organization, Projects lists one\'s own, and the organization opens one of them', (
    tester,
  ) async {
    await World.startBackend(World.work);
    await World.startApp(tester, organizationSource: FixtureOrganization(organizationFor('mia')));
    await tester.tap(find.byKey(const ValueKey('rail projects')));
    await World.settle(tester);
    expect(find.byKey(const ValueKey('my-project demo')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rail organization')));
    await World.settle(tester);
    await tester.scrollUntilVisible(
      _action('goToProject/demo'),
      200,
      scrollable: find
          .descendant(of: find.byKey(const Key('organization-page')), matching: find.byType(Scrollable))
          .first,
    );
    await pressOrganizationAction(tester, 'goToProject/demo');
    await World.settle(tester);
    expect(find.byKey(const ValueKey('organization-project demo')), findsOneWidget);
    expect(find.text('Project Admin pat. Only they change this project.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('organization-project-back')));
    await World.settle(tester);
    expect(find.byKey(const ValueKey('my-project demo')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the rail opens the organization under Set up, after Projects', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester, organizationSource: FixtureOrganization(organizationFor('mia')));
    final projects = tester.getTopLeft(find.byKey(const ValueKey('rail projects')));
    final organization = find.byKey(const ValueKey('rail organization'));
    expect(tester.getTopLeft(organization).dy, greaterThan(projects.dy));
    await tester.tap(organization);
    await World.settle(tester);
    expect(find.byType(OrganizationPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  // Harm: a person is offered what the store then refuses, or takes the page's offer for a right they hold.
  group('each person sees only the actions of their roles', () {
    const ownerOnly = [
      'addProject',
      'addHost',
      'addOrganizationOwner',
      'revokeCard/mia',
      'changeProjectAdmin/demo',
      'removeProject/demo',
      'removeHost/build',
    ];

    testWidgets('an organization owner has the structure, and only their own card', (tester) async {
      await _pump(tester, 'olive');
      for (final id in ownerOnly) {
        expect(_action(id), findsOneWidget, reason: id);
      }
      expect(_action('changeCard'), findsOneWidget);
      expect(_action('withdrawCard'), findsOneWidget);
      expect(_action('revokeCard/olive'), findsNothing, reason: 'Their own card is withdrawn, not revoked.');
      expect(_action('revokeCard/rex'), findsNothing, reason: 'A revoked card has nothing left to revoke.');
      expect(_action('goToProject/demo'), findsNothing, reason: 'They are not in it.');
      expect(_action('openHost/build'), findsNothing, reason: 'They are not its host admin.');
      expect(_action('enterHost/spare'), findsOneWidget);
    });

    for (final (me, opens) in const [
      ('pat', 'goToProject/demo'),
      ('mia', 'goToProject/demo'),
      ('hana', 'openHost/build'),
    ]) {
      testWidgets('$me changes nothing of the structure and has their own row and $opens', (tester) async {
        await _pump(tester, me);
        for (final id in ownerOnly) {
          expect(_action(id), findsNothing, reason: id);
        }
        expect(_action('changeCard'), findsOneWidget);
        expect(_action('withdrawCard'), findsOneWidget);
        expect(_action(opens), findsOneWidget);
      });
    }

    testWidgets('a person with no card reads everything with no buttons, and is offered Add me', (tester) async {
      await _pump(tester, 'stranger');
      expect(find.text('You are not in acme yet'), findsOneWidget);
      expect(_action('addCard'), findsOneWidget);
      for (final id in [...ownerOnly, 'changeCard', 'withdrawCard']) {
        expect(_action(id), findsNothing, reason: id);
      }
      expect(find.text('demo'), findsOneWidget);
      expect(find.text('hana'), findsOneWidget);
    });

    testWidgets('a revoked person holds no role and is not offered a new card', (tester) async {
      await _pump(tester, 'rex');
      for (final id in [...ownerOnly, 'changeCard', 'withdrawCard', 'addCard']) {
        expect(_action(id), findsNothing, reason: id);
      }
      expect(find.textContaining('My card: revoked'), findsOneWidget);
    });

    testWidgets('an owner whose card was revoked holds no owner action', (tester) async {
      await _pump(
        tester,
        'olive',
        view: organizationFor(
          'olive',
          persons: const [OrganizationPerson(login: 'olive', standing: CardStanding.revoked)],
        ),
      );
      for (final id in ownerOnly) {
        expect(_action(id), findsNothing, reason: id);
      }
    });
  });

  // Harm: the block above the lists pushes the important ones out of sight, or a warning folds away with it.
  testWidgets('the head is one line, and an only owner with no backup key is warned in it', (tester) async {
    final (_, organization, _) = await _pump(tester, 'olive');
    final view = organization.view!;
    expect(find.text(view.name), findsWidgets);
    expect(find.textContaining('Choose another Porelo organization'), findsNothing, reason: 'in the menu');
    final warning = find.byKey(const Key('organization-owner-warning'));
    final holdsIt = view.isOwner && view.owners.length == 1 && !view.ownersWithBackup.contains(view.me);
    expect(holdsIt, isTrue, reason: 'this fixture is an only owner with no backup key');
    expect(warning, findsOneWidget);
    await tester.tap(find.byKey(ValueKey<String>('explanation-fold organization')));
    await tester.pumpAndSettle();
    expect(warning, findsOneWidget, reason: 'it never folds away');
    final line = tester.getCenter(find.byKey(const Key('organization-refresh'))).dy;
    expect((tester.getCenter(warning).dy - line).abs(), lessThan(Sizes.rowIcon), reason: 'one line');
    expect(
      tester.getBottomLeft(find.byKey(const Key('organization-refresh'))).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.text('People').first).dy),
      reason: 'and the lists begin under it',
    );
  });

  // Harm: the warning that leads to the owners leads nowhere, when the list is far down or folded.
  testWidgets('the warning opens Organization owners, wherever they are', (tester) async {
    await _pump(tester, 'olive', size: const Size(400, 500));
    await tester.tap(find.byKey(ValueKey<String>('explanation-fold organization')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('organization-owner-warning')));
    await tester.pumpAndSettle();
    final title = find.text('Organization owners');
    expect(title, findsOneWidget);
    expect(tester.getTopLeft(title).dy, inInclusiveRange(0, 500), reason: 'scrolled to');
    expect(find.textContaining('backup key', findRichText: true), findsWidgets);
  });

  // Harm: scrolling down and back closes an explanation that was being read.
  testWidgets('scrolling down and back leaves the explanation open', (tester) async {
    await _pump(tester, 'olive', size: const Size(400, 200));
    expect(find.byKey(ValueKey<String>('explanation-fold organization')), findsOneWidget);
    final page = find.byKey(const Key('organization-page'));
    await tester.drag(page, const Offset(0, -3000));
    await tester.pumpAndSettle();
    await tester.drag(page, const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey<String>('explanation-fold organization')), findsOneWidget);
  });

  // Harm: an unasked or revoked card reads as a good one, and someone is trusted who should not be.
  testWidgets("a card's state is said, never read as trusted", (tester) async {
    await _pump(tester, 'olive');
    expect(find.textContaining('GitHub not reached, asked again on the next read'), findsOneWidget);
    expect(find.textContaining('revoked'), findsOneWidget);
    expect(find.textContaining('My card'), findsNothing, reason: 'a normal state is not described');
    expect(find.textContaining('Kept in the GitHub organization acme'), findsOneWidget);
  });

  // Harm: a row names a person's standing or a project's admin wrongly, and the wrong person is asked.
  testWidgets('rows say who holds what, and how one stands in a project', (tester) async {
    await _pump(tester, 'mia');
    expect(find.textContaining('Project Admin pat'), findsOneWidget);
    expect(find.textContaining('you are a member'), findsOneWidget);
    expect(find.textContaining('you are not a member'), findsOneWidget);
    expect(find.textContaining('203.0.113.7:22'), findsOneWidget);
    expect(find.textContaining('no address yet'), findsOneWidget);
    expect(find.textContaining('mia (you)'), findsOneWidget);
  });

  // Harm: the wrong change is signed for the wrong thing, or without what the store needs to refuse a stale one.
  group('each action asks the store for what it says', () {
    // Harm: a project named so reads as the one every machine has, and its rows cannot be told apart.
    testWidgets('a project may not take the name of the Default project', (tester) async {
      final (fixture, _, _) = await _pump(tester, 'olive');
      await pressOrganizationAction(tester, 'addProject');
      await tester.enterText(find.byKey(const Key('organization-name')), 'Default');
      await _pick(tester, const Key('organization-person'), 'pat');
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(find.textContaining('the project every machine has'), findsOneWidget);
      expect(fixture.writes, isEmpty);
    });

    testWidgets('Add a project names the project and the project admin, and no host', (tester) async {
      final (fixture, _, _) = await _pump(tester, 'olive');
      await pressOrganizationAction(tester, 'addProject');
      expect(find.textContaining('No machine is chosen here'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('organization-name')), 'fresh');
      await _pick(tester, const Key('organization-person'), 'pat');
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      final write = fixture.writes.single;
      expect(write.change, OrganizationChange.addProject);
      expect(write.input, {'project': 'fresh', 'admin': 'pat'});
      expect(write.person, 'olive');
      expect(write.base, 'r1');
      expect(write.id, isNotEmpty);
    });

    testWidgets('a person whose card holds roles can be named, and a revoked one cannot', (tester) async {
      await _pump(tester, 'olive');
      await pressOrganizationAction(tester, 'addHost');
      await tester.tap(find.byKey(const Key('organization-person')));
      await tester.pumpAndSettle();
      Finder offered(String login) => find.widgetWithText(DropdownMenuItem<String>, login);
      expect(offered('hana'), findsWidgets);
      expect(offered('nora'), findsWidgets);
      expect(offered('rex'), findsNothing);
    });

    testWidgets('Add a host names the host and its first host admin', (tester) async {
      final (fixture, _, _) = await _pump(tester, 'olive');
      await pressOrganizationAction(tester, 'addHost');
      await tester.enterText(find.byKey(const Key('organization-name')), 'build-2');
      await _pick(tester, const Key('organization-person'), 'hana');
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.change, OrganizationChange.addHost);
      expect(fixture.writes.single.input, {'host': 'build-2', 'admin': 'hana'});
    });

    testWidgets('a name no project or host can have is refused before the store is asked', (tester) async {
      final (fixture, _, _) = await _pump(tester, 'olive');
      await pressOrganizationAction(tester, 'addHost');
      await tester.enterText(find.byKey(const Key('organization-name')), 'Not/A Host');
      await _pick(tester, const Key('organization-person'), 'hana');
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes, isEmpty);
      expect(find.textContaining('one DNS label'), findsOneWidget);
    });

    for (final (id, change, input) in const [
      ('revokeCard/mia', OrganizationChange.revokeCard, {'login': 'mia'}),
      ('withdrawCard', OrganizationChange.revokeCard, {'login': 'olive'}),
      ('removeProject/demo', OrganizationChange.removeProject, {'project': 'demo'}),
      ('removeHost/build', OrganizationChange.removeHost, {'host': 'build'}),
      ('removeOrganizationOwner/olive', OrganizationChange.removeOrganizationOwner, {'login': 'olive'}),
    ]) {
      testWidgets('$id asks to be confirmed, then asks the store', (tester) async {
        final (fixture, _, _) = await _pump(tester, 'olive', view: organizationFor('olive', owners: ['olive', 'pat']));
        await pressOrganizationAction(tester, id);
        expect(fixture.writes, isEmpty, reason: 'Nothing is signed before it is confirmed.');
        await tester.tap(find.byKey(const Key('organization-confirm')));
        await tester.pumpAndSettle();
        expect(fixture.writes.single.change, change);
        expect(fixture.writes.single.input, input);
      });
    }

    testWidgets('Change the project admin… names another trusted person', (tester) async {
      final (fixture, _, _) = await _pump(tester, 'olive');
      await pressOrganizationAction(tester, 'changeProjectAdmin/demo');
      await _pick(tester, const Key('organization-person'), 'hana');
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.change, OrganizationChange.changeProjectAdmin);
      expect(fixture.writes.single.input, {'project': 'demo', 'admin': 'hana'});
    });

    testWidgets('Add an organization owner names a trusted person', (tester) async {
      final (fixture, _, _) = await _pump(tester, 'olive');
      await pressOrganizationAction(tester, 'addOrganizationOwner');
      await _pick(tester, const Key('organization-person'), 'mia');
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.change, OrganizationChange.addOrganizationOwner);
      expect(fixture.writes.single.input, {'login': 'mia'});
    });

    testWidgets('Cancel asks the store for nothing', (tester) async {
      final (fixture, _, _) = await _pump(tester, 'olive');
      await pressOrganizationAction(tester, 'removeProject/demo');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fixture.writes, isEmpty);
    });

    testWidgets('Go to the project and the host page go there', (tester) async {
      final (_, _, opened) = await _pump(tester, 'olive', view: organizationFor('hana'));
      await pressOrganizationAction(tester, 'openHost/build');
      expect(opened.host, 'build');
      await pressOrganizationAction(tester, 'goToProject/other');
      expect(opened.project, 'other');
    });
  });

  // Harm: a person files a key that is not theirs to file, or believes GitHub vouched for it.
  group('Add me and Change my key', () {
    const listed = OrganizationKey(fingerprint: 'SHA256:mine', label: 'in your ssh agent', vouched: true);
    const unlisted = OrganizationKey(fingerprint: 'SHA256:other', label: 'in your ssh agent', vouched: false);
    const unknown = OrganizationKey(fingerprint: 'SHA256:maybe', label: 'in your ssh agent', vouched: null);

    testWidgets('files the key the source lists', (tester) async {
      final (fixture, _, _) = await _pump(tester, 'stranger', keys: const [listed]);
      await pressOrganizationAction(tester, 'addCard');
      expect(find.textContaining('GitHub lists this key for stranger'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('organization-confirm'))).onPressed, isNull);
      await tester.enterText(find.byKey(const Key('organization-card-name')), 'Sam Stranger');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.change, OrganizationChange.addCard);
      expect(fixture.writes.single.input, {'key': 'SHA256:mine', 'login': 'stranger', 'name': 'Sam Stranger'});
    });

    testWidgets('a key the source does not list cannot be filed, and says so', (tester) async {
      final (fixture, _, _) = await _pump(tester, 'stranger', keys: const [unlisted]);
      await pressOrganizationAction(tester, 'addCard');
      expect(find.textContaining('GitHub does not list this key for stranger'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byKey(const Key('organization-confirm')));
      expect(button.onPressed, isNull);
      expect(fixture.writes, isEmpty);
    });

    testWidgets('a source that cannot say reads as that, never as listed', (tester) async {
      await _pump(tester, 'stranger', keys: const [unknown]);
      await pressOrganizationAction(tester, 'addCard');
      expect(find.textContaining('GitHub could not say'), findsOneWidget);
      expect(find.textContaining('lists this key'), findsNothing);
    });

    testWidgets('no key at all says what to do', (tester) async {
      await _pump(tester, 'stranger');
      await pressOrganizationAction(tester, 'addCard');
      expect(find.textContaining('No key is in your ssh agent'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('organization-confirm'))).onPressed, isNull);
    });

    testWidgets('Change my key writes the new key', (tester) async {
      final (fixture, _, _) = await _pump(tester, 'mia', keys: const [listed]);
      await pressOrganizationAction(tester, 'changeCard');
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.change, OrganizationChange.changeCard);
      expect(fixture.writes.single.input, {'key': 'SHA256:mine'});
    });
  });

  group('what a walk of the window found', () {
    // Harm: a button that can only fail, on the row of the one person who must stay.
    testWidgets('the last organization owner is offered no removal', (tester) async {
      await _pump(tester, 'olive');
      expect(_action('removeOrganizationOwner/olive'), findsNothing);
    });

    // Harm: a person is named owner who already is one, and only the store's refusal tells them.
    testWidgets('naming another owner offers only people who are not one', (tester) async {
      await _pump(tester, 'olive', view: organizationFor('olive', owners: ['olive', 'pat']));
      await pressOrganizationAction(tester, 'addOrganizationOwner');
      await tester.tap(find.byKey(const Key('organization-person')));
      await tester.pumpAndSettle();
      expect(find.text('mia').hitTestable(), findsOneWidget);
      expect(find.text('olive (you)').hitTestable(), findsNothing);
      expect(find.text('pat').hitTestable(), findsNothing);
    });

    // Harm: an owner who has a backup key is warned of nothing, but sees no sign it was made.
    testWidgets('an owner with a backup key says so', (tester) async {
      await _pump(tester, 'olive', view: organizationFor('olive', ownersWithBackup: ['olive']));
      expect(find.text('organization owner · has a backup key'), findsOneWidget);
    });

    // Harm: the rail says one number and the page it opens lists another.
    test('the rail counts what the My projects page lists', () {
      int count(OrganizationView? view) => projectsInRail(view, onMachines: 7, fromOrganization: true);
      expect(count(organizationFor('olive')), 0, reason: 'They hold no role in either.');
      expect(count(organizationFor('pat')), 1, reason: 'A role in one of two; Default and local ones are not counted.');
      expect(
        count(
          organizationFor(
            'pat',
            moreProjects: const [
              OrganizationProject(name: 'fresh', admins: ['pat'], opened: false),
            ],
          ),
        ),
        1,
        reason: 'One with no repository yet stands on the Organization page.',
      );
      expect(count(null), 0, reason: 'With nothing read the page has no rows.');
      expect(projectsInRail(organizationFor('pat'), onMachines: 7), 7, reason: 'All projects on the machines.');
      expect(projectsInRail(null, onMachines: 7), 7);
    });

    // Harm: a closed explanation back on every visit, pushing the page down.
    // Harm: the card goes to the organization under another key than the one the person chose.
    testWidgets('changing the key sends the key chosen, and never offers the one the card has', (tester) async {
      const persons = [OrganizationPerson(login: 'olive', standing: CardStanding.trusted, key: 'SHA256:old')];
      final (fixture, _, _) = await _pump(
        tester,
        'olive',
        view: organizationFor('olive', persons: persons),
        keys: const [
          OrganizationKey(fingerprint: 'SHA256:old', vouched: true),
          OrganizationKey(fingerprint: 'SHA256:first', vouched: true),
          OrganizationKey(fingerprint: 'SHA256:second', vouched: true),
        ],
      );
      await pressOrganizationAction(tester, 'changeCard');
      await tester.tap(find.byKey(const Key('organization-key')));
      await tester.pumpAndSettle();
      expect(find.text('SHA256:old').hitTestable(), findsNothing);
      await tester.tap(find.text('SHA256:second').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.input['key'], 'SHA256:second');
    });

    // Harm: a card is filed under another key than the one the person chose, on their first step in.
    testWidgets('Add me sends the key chosen', (tester) async {
      final (fixture, _, _) = await _pump(
        tester,
        'nobody',
        view: organizationFor('', persons: const []),
        keys: const [
          OrganizationKey(fingerprint: 'SHA256:first', vouched: true),
          OrganizationKey(fingerprint: 'SHA256:second', vouched: true),
        ],
      );
      await pressOrganizationAction(tester, 'addCard');
      await tester.enterText(find.byKey(const Key('organization-card-login')), 'nora');
      await tester.enterText(find.byKey(const Key('organization-card-name')), 'Nora');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-key')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SHA256:second').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.change, OrganizationChange.addCard);
      expect(fixture.writes.single.input['key'], 'SHA256:second');
    });

    group('accepting a new card', () {
      const key = 'AAAAC3NzaC1lZDI1NTE5AAAAIKn6IPaRukSTWN/i3bjSm8ARCGDymgqyDGgVDZ2gFjrF';

      // Harm: a stranger's key let in without the owner seeing which key it is.
      test('names the key the card holds, as ssh-keygen does', () {
        expect(
          fingerprintOfCard('login: "a"\nkey: "ssh-ed25519 $key"\n'),
          'SHA256:RB7a9w45suMCNHu1y5jz0ioAs1NMjrEkJZ6n8rWgPtE',
        );
        expect(fingerprintOfCard('login: "a"\n'), isNull);
      });

      Future<FixtureOrganization> chosen(WidgetTester tester, String words) async {
        tester.view.physicalSize = const Size(1400, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final directory = Directory.systemTemp.createTempSync('card');
        addTearDown(() => directory.deleteSync(recursive: true));
        final file = File('${directory.path}/card')..writeAsStringSync(words);
        final fixture = FixtureOrganization(organizationFor('olive'));
        final organization = Organization(fixture);
        addTearDown(organization.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OrganizationPage(
                organization: organization,
                pickFile: ({initialDirectory, title}) async => file.path,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await pressOrganizationAction(tester, 'replaceCard/mia');
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const Key('organization-card-file')));
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        return fixture;
      }

      testWidgets('shows the key, and only then asks the store with that file', (tester) async {
        final fixture = await chosen(tester, 'key: "ssh-ed25519 $key"\n');
        expect(find.textContaining('SHA256:RB7a9w45suMCNHu1y5jz0ioAs1NMjrEkJZ6n8rWgPtE'), findsOneWidget);
        await tester.tap(find.byKey(const Key('organization-confirm')));
        await tester.pumpAndSettle();
        expect(fixture.writes.single.change, OrganizationChange.replaceCard);
        expect(fixture.writes.single.input['login'], 'mia');
        expect(fixture.writes.single.input['card'], endsWith('/card'));
      });

      testWidgets('a file naming no key cannot be accepted', (tester) async {
        final fixture = await chosen(tester, 'not a card');
        expect(find.text('This is no card: it names no key.'), findsOneWidget);
        await tester.tap(find.byKey(const Key('organization-confirm')), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(fixture.writes, isEmpty);
      });
    });
  });

  // Harm: a refused change reads as done, or a change is signed twice.
  group('nothing is shown before the store answered', () {
    // Harm: a refused removal is mistaken for a completed removal or loses its refusal on closing the dialog.
    testWidgets("a removal's refusal stays in its provisional row until dropped", (tester) async {
      final (fixture, _, _) = await _pump(tester, 'olive', view: organizationFor('olive', owners: ['olive', 'pat']));
      fixture.refuseNext = const OrganizationRefused('The store refused this.');
      await pressOrganizationAction(tester, 'removeOrganizationOwner/olive');
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('The store refused this.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await pressOrganizationAction(tester, 'dropChange/organization-owners/olive');
      expect(_action('removeOrganizationOwner/olive'), findsOneWidget);
    });

    testWidgets('a taken change shows only once it is read back', (tester) async {
      final (fixture, _, _) = await _pump(tester, 'olive');
      fixture.afterWrite = (_) => organizationFor('olive');
      await pressOrganizationAction(tester, 'removeProject/demo');
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('demo'), findsOneWidget, reason: 'The store still lists it.');
      expect(find.byType(AlertDialog), findsNothing);
    });

    test('the same change gets the same id until it was answered', () async {
      final fixture = FixtureOrganization(organizationFor('olive'));
      final organization = Organization(fixture);
      addTearDown(organization.dispose);
      await organization.refresh();
      const input = {'project': 'demo'};
      fixture.refuseNext = const OrganizationRefused('The store did not answer.', answered: false);
      await organization.write(OrganizationChange.removeProject, input);
      fixture.refuseNext = const OrganizationRefused('The store moved on.');
      await organization.write(OrganizationChange.removeProject, input);
      await organization.write(OrganizationChange.removeProject, input);
      await organization.write(OrganizationChange.removeProject, const {'project': 'other'});
      final ids = [for (final write in fixture.writes) write.id];
      expect(ids[1], ids[0], reason: 'Asked again after no answer: the store can answer the same.');
      expect(ids[2], isNot(ids[1]), reason: 'It was answered: this is a new request.');
      expect(ids[3], isNot(ids[2]));
    });

    test('a write is against the revision last read', () async {
      final fixture = FixtureOrganization(organizationFor('olive'));
      final organization = Organization(fixture);
      addTearDown(organization.dispose);
      await organization.refresh();
      await organization.write(OrganizationChange.removeProject, const {'project': 'demo'});
      expect(fixture.writes.single.base, 'r1');
    });
  });

  // Harm: an unreachable store reads as an empty organization, and people conclude nobody is in it.
  group('absence reads as absence', () {
    testWidgets('a store never read says why and shows no empty sections', (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fixture = FixtureOrganization(organizationFor('olive'))
        ..refuseReads = const OrganizationRefused('The organization could not be read.');
      final organization = Organization(fixture);
      addTearDown(organization.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OrganizationPage(organization: organization)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('The organization could not be read.'), findsOneWidget);
      expect(find.textContaining('People ('), findsNothing);
    });

    testWidgets('a store that stops answering keeps the last list and says so', (tester) async {
      final (fixture, organization, _) = await _pump(tester, 'olive');
      fixture.refuseReads = const OrganizationRefused('The organization could not be read.');
      await organization.refresh();
      await tester.pumpAndSettle();
      expect(find.text('The organization could not be read.'), findsOneWidget);
      expect(find.text('demo'), findsOneWidget);
    });
  });

  testWidgets('a section filter narrows its own rows', (tester) async {
    await _pump(tester, 'olive');
    await tester.tap(find.byKey(const ValueKey('organization-projects-search')));
    await World.settle(tester);
    await tester.enterText(find.byKey(const ValueKey('organization-projects-filter')), 'oth');
    await tester.pumpAndSettle();
    expect(_action('removeProject/other'), findsOneWidget);
    expect(_action('removeProject/demo'), findsNothing);
    expect(_action('revokeCard/mia'), findsOneWidget, reason: 'Another section keeps its rows.');
  });

  // Harm: the help said the repository bears the GitHub organization's name, and it bears the person's.
  testWidgets('the help names the forge\'s own word where it knows the forge', (tester) async {
    await _pump(tester, 'olive', view: organizationFor('olive', forge: 'github.com'));
    expect(find.textContaining('inside the GitHub organization'), findsOneWidget);
    expect(find.textContaining('of the same name'), findsNothing);
  });

  testWidgets('the help of another forge names none', (tester) async {
    await _pump(tester, 'olive', view: organizationFor('olive', forge: 'forge.example.org'));
    expect(find.textContaining('inside the GitHub'), findsNothing);
    expect(find.textContaining("inside your forge's organization"), findsOneWidget);
  });

  // Harm: once the list exists an unlisted owner still changes the organization, or a listed person cannot.
  group('Organization Admins', () {
    testWidgets('while the list is absent an owner does the work and may list someone', (tester) async {
      await _pump(tester, 'olive');
      expect(_action('addProject'), findsOneWidget);
      await pressOrganizationAction(tester, 'addOrganizationAdmin');
      expect(find.textContaining('only the people listed do this work'), findsOneWidget);
    });

    testWidgets('once it exists an unlisted owner keeps only an owner\'s work', (tester) async {
      await _pump(tester, 'olive', view: organizationFor('olive', organizationAdmins: const ['mia']));
      expect(_action('addProject'), findsNothing);
      expect(_action('addOrganizationOwner'), findsOneWidget);
      expect(_action('removeOrganizationAdmin/mia'), findsOneWidget);
    });

    testWidgets('a listed person does it, and does not name owners or admins', (tester) async {
      await _pump(tester, 'mia', view: organizationFor('mia', organizationAdmins: const ['mia']));
      expect(_action('addProject'), findsOneWidget);
      expect(_action('addHost'), findsOneWidget);
      expect(_action('addOrganizationOwner'), findsNothing);
      expect(_action('addOrganizationAdmin'), findsNothing);
    });
  });

  // Harm: a list sorted by what a person needs falls back to its first order when the page is left.
  testWidgets('a list keeps its sort, and a project sorts by machine', (tester) async {
    await _pump(tester, 'olive', size: const Size(1280, 2000));
    final bucket = PageStorage.of(tester.element(find.byKey(const ValueKey('organization-projects-sort'))));
    await tester.tap(find.byKey(const ValueKey('organization-projects-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('organization-projects-sort Machine')));
    await tester.pumpAndSettle();
    expect(find.text('Machine'), findsOneWidget);
    expect(find.text('Name'), findsWidgets, reason: 'another list keeps its own order');
    expect(
      bucket.readState(
        tester.element(find.byKey(const ValueKey('organization-projects-sort'))),
        identifier: 'organization-projects',
      ),
      isNotNull,
    );
  });

  // Harm: a phone opens on a page as long as all its lists together, so a person finds nothing below the first.
  testWidgets('on a phone only the first list starts open', (tester) async {
    await _pump(tester, 'olive', size: const Size(380, 2400));
    expect(_action('revokeCard/mia'), findsOneWidget);
    expect(_action('removeHost/build'), findsNothing);
  });

  // Harm: on a narrow window the actions run off the side, and an owner cannot reach them.
  testWidgets('the page fits a phone', (tester) async {
    await _pump(tester, 'olive', size: const Size(380, 2400));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('organization-hosts-fold')));
    await tester.pumpAndSettle();
    expect(_action('removeHost/build'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Harm: a state from before the store went away, or a change the store refused, is read as all there is.
  testWidgets('a stale state and what the store warns of are said', (tester) async {
    final view = organizationFor('mia');
    final organization = Organization(
      FixtureOrganization(
        OrganizationView(
          name: view.name,
          keptIn: view.keptIn,
          vouchedBy: view.vouchedBy,
          revision: view.revision,
          me: view.me,
          persons: view.persons,
          projects: view.projects,
          hosts: view.hosts,
          owners: view.owners,
          stale: true,
          notes: const ['mia is the only owner and has no backup key.'],
        ),
      ),
    );
    addTearDown(organization.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OrganizationPage(organization: organization)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('organization-stale')), findsOneWidget);
    expect(find.text('mia is the only owner and has no backup key.'), findsOneWidget);
  });

  group('a computer with no organization', () {
    Future<(FixtureOrganization, Organization)> none(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fixture = FixtureOrganization(
        organizationFor('olive'),
        keys: const [OrganizationKey(fingerprint: 'SHA256:k', vouched: true)],
      )..refuseReads = const OrganizationRefused('no organization here', reason: 'no-organization');
      final organization = Organization(fixture);
      addTearDown(organization.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrganizationPage(
              settings: Settings(MemorySettingsStore()),
              organization: organization,
              onProject: (_) {},
              onHost: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (fixture, organization);
    }

    // Harm: a person on a new computer has no way into their organization.
    // Harm: at this moment a person has both a GitHub organization and this one, and the bare word means either.
    testWidgets('it says Porelo organization wherever both could be meant', (tester) async {
      await none(tester);
      expect(find.text('This computer reads no Porelo organization yet'), findsOneWidget);
      expect(find.text('What is the Porelo organization?'), findsOneWidget);
      expect(find.text('Create the Porelo organization…'), findsOneWidget);
      await _open(tester, find.text('Choose the Porelo organization…'));
      expect(find.text('Choose the Porelo organization'), findsOneWidget);
      expect(find.text("The Porelo organization's repository address"), findsOneWidget);
      expect(find.textContaining('use *Create the Porelo organization…*'), findsOneWidget);
      expect(find.textContaining('GitHub'), findsNothing, reason: 'no address is known, so no forge is named');
      expect(find.textContaining("your forge's organization"), findsWidgets);
    });

    testWidgets('choosing asks for the address and sets up', (tester) async {
      final (fixture, _) = await none(tester);
      expect(find.text('no organization here'), findsNothing);
      await _open(tester, find.byKey(const ValueKey('chooseOrganization')));
      await tester.enterText(find.byKey(const Key('organization-address')), 'git@github.com:acme/org.git');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.change, OrganizationChange.chooseOrganization);
      expect(fixture.writes.single.input, {'address': 'git@github.com:acme/org.git'});
    });

    // Harm: a person expects Porelo to make the repository, and is stopped with no idea why (the operator's 10:31Z word).
    // Harm: a token pasted with the address reaches a process's arguments, where others on the machine read them.
    testWidgets('an address holding a token cannot be given', (tester) async {
      final (fixture, _) = await none(tester);
      await _open(tester, find.byKey(const ValueKey('chooseOrganization')));
      await tester.enterText(
        find.byKey(const Key('organization-address')),
        'https://tok123@forge.example/acme/org.git',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-confirm')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(fixture.writes, isEmpty);
    });

    testWidgets('creating says to make the empty repository first, and fills it', (tester) async {
      final (fixture, _) = await none(tester);
      await _open(tester, find.byKey(const ValueKey('createOrganization')));
      expect(find.textContaining('Make an empty repository on your forge first'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('organization-address')), 'git@github.com:acme/org.git');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.change, OrganizationChange.createOrganization);
    });

    // Harm: right after creating an organization on GitHub, *My forges* said 0.
    testWidgets('creating from the window lists its forge, asking for nothing', (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fixture = FixtureOrganization(
        organizationFor('olive'),
        keys: const [OrganizationKey(fingerprint: 'SHA256:k', vouched: true)],
      )..refuseReads = const OrganizationRefused('no organization here', reason: 'no-organization');
      await World.startBackend(World.work);
      await World.startApp(tester, organizationSource: fixture);
      await tester.tap(find.byKey(const ValueKey('rail organization')));
      await World.settle(tester);
      await tester.tap(find.byKey(const ValueKey('createOrganization')));
      await World.settle(tester);
      await tester.enterText(find.byKey(const Key('organization-address')), 'git@forge.example.org:acme/org.git');
      await World.settle(tester);
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await World.settle(tester);
      expect(fixture.writes.single.change, OrganizationChange.createOrganization);
      expect([for (final entry in World.forges.entries) entry.address], contains('forge.example.org'));
    });

    // Harm: in the foo test creating failed at the end, on what could have been said before it.
    group('asking what creating needs', () {
      Future<_Checking> dialog(WidgetTester tester) async {
        tester.view.physicalSize = const Size(1400, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final fixture = _Checking(organizationFor('olive'))
          ..refuseReads = const OrganizationRefused('no organization here', reason: 'no-organization');
        final organization = Organization(fixture);
        addTearDown(organization.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OrganizationPage(organization: organization, onHost: (_) {}, onProject: (_) {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _open(tester, find.byKey(const ValueKey('createOrganization')));
        await tester.enterText(find.byKey(const Key('organization-address')), 'git@forge.example.org:acme/org.git');
        await tester.pumpAndSettle();
        return fixture;
      }

      testWidgets('shows Core\'s words and next step, and files nothing', (tester) async {
        final fixture = await dialog(tester);
        await tester.tap(find.byKey(const Key('organization-founding-check')));
        await tester.pumpAndSettle();
        expect(fixture.asked, ['git@forge.example.org:acme/org.git']);
        expect(find.text('The key is not listed. List it on the forge.'), findsOneWidget);
        expect(find.text('This machine is ready.'), findsOneWidget);
        expect(fixture.writes, isEmpty);
      });

      testWidgets('an address changed since says nothing of the new one', (tester) async {
        await dialog(tester);
        await tester.tap(find.byKey(const Key('organization-founding-check')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('organization-address')), 'git@forge.example.org:acme/two.git');
        await tester.pumpAndSettle();
        expect(find.text('This machine is ready.'), findsNothing);
      });

      testWidgets('a late answer of the old address is not shown', (tester) async {
        final fixture = await dialog(tester);
        final held = Completer<void>();
        fixture.hold = held.future;
        await tester.tap(find.byKey(const Key('organization-founding-check')));
        await tester.pump();
        await tester.enterText(find.byKey(const Key('organization-address')), 'git@forge.example.org:acme/two.git');
        await tester.pump();
        held.complete();
        await tester.pumpAndSettle();
        expect(find.text('This machine is ready.'), findsNothing);
      });

      // Harm: a token in the address reaches a command line, which other programs read.
      testWidgets('an address with a token in its query is not asked about', (tester) async {
        final fixture = await dialog(tester);
        await tester.enterText(
          find.byKey(const Key('organization-address')),
          'https://forge.example.org/acme/org.git?access_token=example',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('organization-founding-check')));
        await tester.pumpAndSettle();
        expect(fixture.asked, isEmpty);
      });

      testWidgets('a fault that is no refusal does not leave it asking', (tester) async {
        final fixture = await dialog(tester);
        fixture.failCheck = true;
        await tester.tap(find.byKey(const Key('organization-founding-check')));
        await tester.pumpAndSettle();
        expect(find.text('Porelo could not say what creating needs here.'), findsOneWidget);
        expect(find.text('What does creating it need?'), findsOneWidget);
      });

      testWidgets('a refusal is said in its words', (tester) async {
        final fixture = await dialog(tester);
        fixture.refuseCheck = const OrganizationRefused('The key store is not ready.');
        await tester.tap(find.byKey(const Key('organization-founding-check')));
        await tester.pumpAndSettle();
        expect(find.text('The key store is not ready.'), findsOneWidget);
      });
    });

    // Harm: creating at https works, and the stop comes only at the first machine.
    testWidgets('creating at an https address says so before anything is filed', (tester) async {
      final (fixture, _) = await none(tester);
      await _open(tester, find.byKey(const ValueKey('createOrganization')));
      final word = find.byKey(const Key('organization-https-word'));
      expect(word, findsNothing);
      await tester.enterText(find.byKey(const Key('organization-address')), 'git@github.com:acme/org.git');
      await tester.pumpAndSettle();
      expect(word, findsNothing);
      await tester.enterText(find.byKey(const Key('organization-address')), 'https://github.com/acme/org.git');
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(word).data, allOf(contains('no machine can follow'), contains('git@')));
      expect(fixture.writes, isEmpty);
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.change, OrganizationChange.createOrganization, reason: 'It is allowed.');
    });

    // Harm: creating needs a card, and a person with none cannot make one because no organization is read.
    testWidgets('a card can be made before there is any organization', (tester) async {
      final (fixture, _) = await none(tester);
      await _open(tester, find.byKey(const ValueKey('makeCard')));
      await tester.enterText(find.byKey(const Key('organization-card-login')), 'olive');
      await tester.enterText(find.byKey(const Key('organization-card-name')), 'Olive');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.change, OrganizationChange.addCard);
      expect(fixture.writes.single.base, '');
    });
  });

  // Harm: a person who chose the wrong organization is stuck with it.
  testWidgets('another organization can be chosen, and it says what that does', (tester) async {
    final (fixture, _, _) = await _pump(tester, 'mia');
    await pressOrganizationAction(tester, 'chooseOrganization');
    expect(find.textContaining('reads one Porelo organization'), findsOneWidget);
    expect(find.textContaining('filled by *Create another Porelo organization'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('organization-address')), 'x');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('organization-confirm')));
    await tester.pumpAndSettle();
    expect(fixture.writes.single.input, {'address': 'x', 'replace': 'yes'});
  });

  // Harm: a person who holds one organization cannot start a second, or starts it thinking the first is lost.
  testWidgets('another organization can be created, and it says the first stays', (tester) async {
    final (fixture, _, _) = await _pump(tester, 'mia');
    await pressOrganizationAction(tester, 'createAnotherOrganization');
    expect(find.textContaining('This one stays on its forge'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('organization-address')), 'x');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('organization-confirm')));
    await tester.pumpAndSettle();
    expect(fixture.writes.single.change, OrganizationChange.createOrganization);
    expect(fixture.writes.single.input, {'address': 'x', 'replace': 'yes'});
  });

  group("an owner's recovery of a project", () {
    // Harm: a project whose admins all lost their keys cannot be recovered by anybody.
    testWidgets('an owner adds an admin, and a person already one is not offered', (tester) async {
      final (fixture, _, _) = await _pump(tester, 'olive');
      await pressOrganizationAction(tester, 'addProjectAdmin/demo');
      await tester.tap(find.byKey(const Key('organization-person')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(DropdownMenuItem<String>, 'pat'), findsNothing);
      await tester.tap(find.widgetWithText(DropdownMenuItem<String>, 'hana').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.change, OrganizationChange.addProjectMember);
      expect(fixture.writes.single.input, {'project': 'demo', 'login': 'hana', 'role': 'admin'});
    });

    // Harm: a developer of the project cannot be made its admin: adding them is refused, as they are there already.
    testWidgets("an owner making one of a project's members its admin changes their role", (tester) async {
      final (fixture, _, _) = await _pump(tester, 'olive');
      await pressOrganizationAction(tester, 'addProjectAdmin/demo');
      await tester.tap(find.byKey(const Key('organization-person')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownMenuItem<String>, 'mia').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.change, OrganizationChange.changeProjectMemberRole);
      expect(fixture.writes.single.input, {'project': 'demo', 'login': 'mia', 'role': 'admin'});
    });

    // Harm: a person's card runs out with nobody having seen until when it holds.
    testWidgets('a card says until when it holds', (tester) async {
      final view = organizationFor(
        'olive',
        persons: const [
          OrganizationPerson(login: 'olive', key: 'SHA256:o', standing: CardStanding.trusted, expires: '2028-11-02'),
        ],
      );
      await _pump(tester, 'olive', view: view);
      expect(find.textContaining('until 2028-11-02'), findsOneWidget);
    });

    // Harm: the last admin goes unsaid, and the project stands with nobody to change it.
    testWidgets('an owner removing the last admin is told so, and it is asked for', (tester) async {
      final (fixture, _, _) = await _pump(tester, 'olive');
      await pressOrganizationAction(tester, 'removeProjectAdmin/demo/pat');
      expect(find.textContaining('pat is its last admin'), findsOneWidget);
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.change, OrganizationChange.removeProjectMember);
      expect(fixture.writes.single.input, {'project': 'demo', 'login': 'pat'});
    });

    // Harm: anybody else is offered what only an owner may.
    testWidgets('nobody but an owner is offered it', (tester) async {
      await _pump(tester, 'pat');
      expect(_action('addProjectAdmin/demo'), findsNothing);
      expect(_action('removeProjectAdmin/demo/pat'), findsNothing);
    });
  });
}
