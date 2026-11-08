import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/host_progress.dart';
import 'package:porelo_frontend/src/ui/organization_project_pages.dart';

import '../support/organization_fixtures.dart';

import 'package:porelo_frontend/src/ui/command_menu.dart';

import 'organization_actions.dart';

import 'package:porelo_frontend/src/ui/page_explanation.dart';

Finder _action(String id) => organizationAction(id);

Future<void> _settle(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
  await tester.pumpAndSettle();
}

Future<FixtureOrganization> _page(WidgetTester tester, String me, {ProjectView project = demoProject}) async {
  final fixture = FixtureOrganization(organizationFor(me))..projects = {'demo': project};
  final organization = Organization(fixture);
  addTearDown(organization.dispose);
  await organization.refresh();
  await _settle(tester, OrganizationProjectPage(organization: organization, project: 'demo', onBack: () {}));
  return fixture;
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

class _Central extends FixtureConnections {
  _Central() : super(const ['build']);

  @override
  Future<CentralState> central(String host, String project) async =>
      const CentralState(repositories: [(state: 'ahead', commits: 2)]);
}

class _Connecting extends FixtureConnections {
  Completer<void>? held;
  int attempts = 0;

  @override
  Future<void> connect(String host) async {
    attempts++;
    await held?.future;
    await super.connect(host);
  }
}

void main() {
  // Harm: a refusal or an unopened repository is mistaken for a successfully empty project.
  for (final project in [
    const ProjectView(name: 'demo', revision: 'p1', repositoriesProblem: 'Repository read refused.'),
    const ProjectView(name: 'demo', revision: 'p1', opened: false),
  ]) {
    testWidgets('unread project repositories never count as empty: ${project.opened}', (tester) async {
      await _page(tester, 'pat', project: project);
      final head = tester.widget<PageHead>(find.byType(PageHead).first);
      expect(head.subtitle, isNot(contains('0 repositories')));
      expect(find.textContaining('No repositories yet.'), findsNothing);
      if (project.repositoriesProblem != null) {
        expect(find.text(project.repositoriesProblem!), findsOneWidget);
      }
    });
  }

  // Harm: phone actions for different lists lose the names identifying their targets.
  testWidgets('a phone keeps the project and its inner list titles', (tester) async {
    await _page(tester, 'pat');
    tester.view.physicalSize = const Size(390, 1600);
    await tester.pumpAndSettle();
    for (final title in ['demo', 'Repositories', 'Members']) {
      final text = find.byWidgetPredicate(
        (widget) => widget is Text && widget.key == const Key('leaf-title') && widget.data == title,
      );
      await tester.ensureVisible(text);
      expect(text.hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  // Harm: a person cannot see that approved work waits to go to the central forge, or takes cannot say for up to date.
  group('how a project stands with the central forge', () {
    for (final (answer, words, offers) in [
      (
        '{"read_at":"2026-11-03T15:00:01Z","repositories":[{"repository":"a","state":"ahead","commits":3}]}',
        '3 approved commits not yet at',
        true,
      ),
      ('{"repositories":[{"repository":"a","state":"up-to-date"}]}', 'up to date with', false),
      (
        '{"repositories":[{"repository":"a","state":"ahead","commits":1},{"repository":"c","state":"moved-on"}]}',
        'has moved on: a push would be refused',
        false,
      ),
      (
        '{"repositories":[{"repository":"a","state":"cannot-say","why":"unreachable"}]}',
        'cannot say how it stands with',
        false,
      ),
      ('{"repositories":[]}', 'cannot say how it stands with', false),
      ('not json', 'cannot say how it stands with', false),
    ]) {
      test('$answer says $words', () {
        final state = CentralState.fromAnswer(answer);
        expect(state.words('GitHub'), contains(words));
        expect(state.offersPush, offers);
      });
    }

    // Harm: a machine's words forge a line of the row, or turn its reason round.
    testWidgets('a reason from a machine is shown as text it cannot arrange', (tester) async {
      final organization = Organization(FixtureOrganization(organizationFor('mia')));
      addTearDown(organization.dispose);
      await _settle(
        tester,
        OrganizationProjectsPage(
          organization: organization,
          connections: _Central(),
          onProject: (_) {},
          menuFor: (project, host) => [
            Command(
              id: 'project.pushApprovedMain',
              label: 'Push the approved main…',
              group: project,
              run: () {},
              unavailable: 'refused\nall is well\u202e',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('refused?all is well?'), findsOneWidget);
    });

    // Harm: a grey push whose reason only a hover can find.
    testWidgets('a push that cannot be asked says why in the row', (tester) async {
      final organization = Organization(FixtureOrganization(organizationFor('mia')));
      addTearDown(organization.dispose);
      await _settle(
        tester,
        OrganizationProjectsPage(
          organization: organization,
          connections: _Central(),
          onProject: (_) {},
          menuFor: (project, host) => [
            Command(
              id: 'project.pushApprovedMain',
              label: 'Push the approved main…',
              group: project,
              run: () {},
              unavailable: 'the host is not connected',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Push the approved main: the host is not connected'), findsOneWidget);
    });

    testWidgets('a row offers the push only while commits wait, beside the row', (tester) async {
      var pushed = 0;
      final organization = Organization(FixtureOrganization(organizationFor('mia')));
      addTearDown(organization.dispose);
      final connections = _Central();
      await _settle(
        tester,
        OrganizationProjectsPage(
          organization: organization,
          connections: connections,
          onProject: (_) {},
          menuFor: (project, host) => [
            Command(
              id: 'project.pushApprovedMain',
              label: 'Push the approved main…',
              group: project,
              run: () => pushed++,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('2 approved commits not yet at'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('organization.pushApprovedMain demo')));
      expect(pushed, 1);
    });
  });

  // Harm: a locked member takes their project for one they can work on; a local project cannot be found from here.
  // Harm: a machine takes nothing from such a row, and the first sign comes when a task starts on it.
  group('a repository with no central address', () {
    const project = ProjectView(
      name: 'demo',
      revision: 'p1',
      host: 'build',
      address: 'git@forge.example.org:acme/demo-project.git',
      roles: ['developer', 'admin'],
      repositories: [
        ProjectRepository(name: 'none', address: 'git@forge.example.org:acme/none.git', central: ''),
        ProjectRepository(name: 'has', address: 'git@forge.example.org:acme/has.git', central: 'git@x:acme/has.git'),
        ProjectRepository(name: 'unsaid', address: 'git@forge.example.org:acme/unsaid.git'),
      ],
      repositoriesRevision: 'r7',
      members: [ProjectMember(login: 'pat', role: 'admin', standing: CardStanding.trusted)],
    );

    testWidgets('says so to its Project Admin, who mends it with its own address', (tester) async {
      final fixture = await _page(tester, 'pat', project: project);
      expect(find.textContaining('no central address'), findsOneWidget);
      await pressOrganizationAction(tester, 'nameCentral/none');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.change, OrganizationChange.nameRepositoryCentral);
      expect(fixture.writes.single.input, {
        'project': 'demo',
        'repository': 'none',
        'central': 'git@forge.example.org:acme/none.git',
      });
      expect(find.text('entry: nameRepositoryCentral\n'), findsOneWidget);
      expect(find.textContaining('project.yml in the own repository of project demo'), findsOneWidget);
    });

    // Harm: Porelo's refusal is lost, or an entry from an earlier answer stays beside it.
    testWidgets('a refusal is said in the dialog, and no entry with it', (tester) async {
      final fixture = await _page(tester, 'pat', project: project);
      fixture.refuseNext = const OrganizationRefused('That repository is not in the project.');
      await pressOrganizationAction(tester, 'nameCentral/none');
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('That repository is not in the project.'), findsOneWidget);
      expect(find.byKey(const Key('project-file-entry')), findsNothing);
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('That repository is not in the project.'), findsNothing);
      expect(find.byKey(const Key('project-file-entry')), findsOneWidget);
    });

    testWidgets('offers no mending, and promises none, where it names no address either', (tester) async {
      await _page(
        tester,
        'pat',
        project: const ProjectView(
          name: 'demo',
          revision: 'p1',
          roles: ['developer', 'admin'],
          repositories: [ProjectRepository(name: 'none', central: '')],
          members: [ProjectMember(login: 'pat', role: 'admin', standing: CardStanding.trusted)],
        ),
      );
      expect(find.textContaining('has to be removed and added again'), findsOneWidget);
      expect(find.textContaining('Name one'), findsNothing);
    });

    // Harm: an empty list that does not say what comes first.
    testWidgets('a project with none says how to add one, to its admin', (tester) async {
      await _page(
        tester,
        'pat',
        project: const ProjectView(
          name: 'demo',
          revision: 'p1',
          roles: ['developer', 'admin'],
          members: [ProjectMember(login: 'pat', role: 'admin', standing: CardStanding.trusted)],
        ),
      );
      // A leaf's list stands open on its own page, so the empty one says how at once.
      expect(find.text('No repositories yet. Add one with Add.'), findsOneWidget);
    });

    testWidgets('says so to anyone else, with nothing to press', (tester) async {
      await _page(tester, 'olive', project: project);
      expect(find.textContaining('no central address'), findsOneWidget);
      expect(_action('nameCentral/none'), findsNothing);
    });
  });

  // Harm: a checkout's local copy listed among the organization's projects, as the operator found.
  testWidgets('the list says who is locked, lists no project of this computer alone, and leads to the machines', (
    tester,
  ) async {
    final source = FixtureOrganization(organizationFor('mia'))
      ..listed = const [
        ListedProject(name: 'demo', source: 'organization', role: 'developer', locked: true, host: 'build'),
        ListedProject(name: 'mine', source: 'local'),
      ];
    final organization = Organization(source);
    addTearDown(organization.dispose);
    var others = 0;
    await _settle(
      tester,
      OrganizationProjectsPage(organization: organization, onProject: (_) {}, onOthers: () => others++),
    );
    expect(find.text('locked'), findsOneWidget);
    expect(find.byKey(const ValueKey('my-project mine')), findsNothing);
    await tester.tap(find.byKey(const Key('projects-of-machines')));
    await tester.pumpAndSettle();
    expect(others, 1);
  });

  group('the list of my projects', () {
    Future<List<String>> opened(WidgetTester tester, String me) async {
      final organization = Organization(FixtureOrganization(organizationFor(me)));
      addTearDown(organization.dispose);
      final opened = <String>[];
      await _settle(tester, OrganizationProjectsPage(organization: organization, onProject: opened.add));
      return opened;
    }

    // Harm: Connect navigates without connecting, retries twice, or offers work before the connection succeeds.
    testWidgets('a row connects to its machine, keeps a refusal, and offers work after connecting', (tester) async {
      final organization = Organization(FixtureOrganization(organizationFor('pat')));
      addTearDown(organization.dispose);
      final connections = _Connecting()
        ..held = Completer<void>()
        ..refuseNext = const OrganizationRefused('The machine could not be reached.');
      addTearDown(connections.dispose);
      final opened = <(String, String)>[];
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrganizationProjectsPage(
              organization: organization,
              connections: connections,
              onProject: (_) {},
              onHost: (project, host) => opened.add((project, host)),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final connect = find.byKey(const ValueKey('organization.connectToHost demo'));
      expect(connect, findsOneWidget);
      await tester.tap(connect);
      await tester.pump();
      await tester.tap(connect);
      await tester.pump();
      expect(connections.attempts, 1, reason: 'An unanswered attempt must not start a second connection.');
      expect(opened, isEmpty, reason: 'Connecting must not open a page instead.');
      connections.held!.complete();
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('The machine could not be reached.'), findsOneWidget);
      expect(connections.connected('build'), isFalse);
      connections.held = null;
      await tester.tap(connect);
      await tester.pump();
      await tester.pump();
      expect(connections.asked, ['connect build', 'connect build']);
      expect(connections.connected('build'), isTrue);
      expect(find.textContaining('The machine could not be reached.'), findsNothing);
      expect(connect, findsNothing);
      expect(opened, isEmpty);
      await pressOrganizationAction(tester, 'openOnHost demo');
      expect(opened, [('demo', 'build')]);
      await connections.disconnect('build');
      await tester.pump();
      expect(connect, findsOneWidget, reason: 'A connection ended elsewhere must be offered again here.');
    });

    // Harm: a host lists a project only after a first start, so a member cannot push what the host gathered.
    testWidgets("a project on a host has its menu here, as the host's own list does not name it yet", (tester) async {
      final organization = Organization(FixtureOrganization(organizationFor('pat')));
      addTearDown(organization.dispose);
      var pushed = false;
      await _settle(
        tester,
        OrganizationProjectsPage(
          organization: organization,
          onProject: (_) {},
          menuFor: (project, host) => [
            Command(
              id: 'push',
              label: 'Push $project from $host',
              group: project,
              home: Home.projectMenu,
              run: () => pushed = true,
            ),
          ],
        ),
      );
      await _tap(tester, find.byKey(const ValueKey('organization.projectMenu demo')));
      await _tap(tester, find.text('Push demo from build'));
      expect(pushed, isTrue);
      expect(find.byKey(const ValueKey('organization.projectMenu other')), findsNothing);
    });

    // Harm: a locked member, who may do nothing, is sent to the host.
    testWidgets('a locked member is offered no way to the host', (tester) async {
      final organization = Organization(
        FixtureOrganization(organizationFor('pat'))
          ..listed = const [
            ListedProject(name: 'demo', source: 'organization', role: 'developer', locked: true, host: 'build'),
          ],
      );
      addTearDown(organization.dispose);
      await _settle(tester, OrganizationProjectsPage(organization: organization, onProject: (_) {}, onHost: (_, _) {}));
      expect(find.byKey(const ValueKey('my-project demo')), findsOneWidget);
      expect(find.byKey(const ValueKey('organization.openOnHost demo')), findsNothing);
    });

    // Harm: a person cannot tell where a project of theirs is, or what it holds.
    testWidgets('a project is one row, naming the one host carrying it', (tester) async {
      await opened(tester, 'pat');
      expect(find.byKey(const ValueKey('my-project demo')), findsOneWidget);
      expect(find.textContaining('2 repositories · 2 people · on build'), findsOneWidget);
      expect(find.text('Project Admin'), findsOneWidget);
    });

    // Harm: a person is shown what they are not in, as if they belonged to it.
    testWidgets('it lists only the projects one is in', (tester) async {
      await opened(tester, 'mia');
      expect(find.byKey(const ValueKey('my-project demo')), findsOneWidget);
      expect(find.byKey(const ValueKey('my-project other')), findsNothing);
      expect(find.text('developer'), findsOneWidget);
    });

    testWidgets('a project opens its page', (tester) async {
      final open = await opened(tester, 'mia');
      await tester.tap(find.byKey(const ValueKey('my-project demo')));
      expect(open, ['demo']);
    });

    // Harm: an empty list reads as lost projects, or asks the person to join.
    testWidgets('no project says that an admin adds you, and offers no Join', (tester) async {
      await opened(tester, 'olive');
      expect(find.textContaining('a Project Admin adds you'), findsOneWidget);
      expect(find.text('Join'), findsNothing);
    });

    testWidgets('a store that does not answer says so, and no list reads as empty', (tester) async {
      final fixture = FixtureOrganization(organizationFor('mia'))
        ..refuseReads = const OrganizationRefused('The organization could not be read.');
      final organization = Organization(fixture);
      addTearDown(organization.dispose);
      await _settle(tester, OrganizationProjectsPage(organization: organization, onProject: (_) {}));
      expect(find.text('The organization could not be read.'), findsOneWidget);
      expect(find.textContaining('You are in no project'), findsNothing);
    });
  });

  group("a project's page", () {
    const changes = [
      'changeAddress',
      'addRepository',
      'removeRepository/demo',
      'addMember',
      'memberRole/mia',
      'removeMember/mia',
      'lockMember/mia',
    ];

    // Harm: someone who may not is offered a change, or the one who may cannot find it.
    testWidgets('a project admin has every change, on another admin too', (tester) async {
      await _page(tester, 'pat');
      for (final id in changes) {
        expect(_action(id), findsOneWidget, reason: id);
      }
      expect(_action('removeMember/pat'), findsOneWidget, reason: "The last project admin is the store's to refuse.");
      expect(find.textContaining('Only they change'), findsNothing);
    });

    for (final me in ['mia', 'olive', 'hana']) {
      testWidgets('$me sees every value and no change', (tester) async {
        await _page(tester, me);
        for (final id in changes) {
          expect(_action(id), findsNothing, reason: id);
        }
        expect(find.text('Project Admin pat. Only they change this project.'), findsOneWidget);
        expect(find.text('demo-docs'), findsOneWidget);
        expect(find.textContaining('git@forge.example.org:acme/demo-docs.git'), findsOneWidget);
        expect(find.text('admin'), findsOneWidget);
      });
    }

    // Harm: several admins are decided, and a second one is treated as a member who may change nothing.
    testWidgets('any member with the admin role changes the project', (tester) async {
      await _page(
        tester,
        'mia',
        project: const ProjectView(
          name: 'demo',
          revision: 'p1',
          roles: ['developer', 'admin'],
          members: [
            ProjectMember(login: 'pat', role: 'admin', standing: CardStanding.trusted),
            ProjectMember(login: 'mia', role: 'admin', standing: CardStanding.trusted),
          ],
        ),
      );
      expect(_action('addMember'), findsOneWidget);
      expect(find.textContaining('Only they change'), findsNothing);
    });

    // Harm: a locked person keeps the rights the lock was to stop.
    testWidgets('a locked admin changes nothing, and reads as locked', (tester) async {
      await _page(
        tester,
        'mia',
        project: const ProjectView(
          name: 'demo',
          revision: 'p1',
          members: [ProjectMember(login: 'mia', role: 'admin', standing: CardStanding.trusted, locked: true)],
        ),
      );
      expect(_action('addMember'), findsNothing);
      expect(find.text('locked'), findsNWidgets(2));
    });

    for (final (login, change, label) in const [
      ('mia', OrganizationChange.lockProjectMember, 'Lock'),
      ('nora', OrganizationChange.unlockProjectMember, 'Unlock'),
    ]) {
      testWidgets('$label asks the store for $login', (tester) async {
        final fixture = await _page(tester, 'pat');
        expect(tester.widget<CommandMenu>(_action('lockMember/$login')).commands.first.label, label);
        await pressOrganizationAction(tester, 'lockMember/$login');
        expect(fixture.writes.single.change, change);
        expect(fixture.writes.single.input, {'project': 'demo', 'login': login});
        expect(fixture.writes.single.base, 'p1');
      });
    }

    // Harm: a card that could not be asked about, or a revoked one, reads as trusted beside a member's name.
    testWidgets("a member's card is said as it stands", (tester) async {
      await _page(tester, 'pat');
      expect(find.text('trusted'), findsNWidgets(2));
      expect(find.text('not yet'), findsOneWidget);
      expect(find.text('revoked'), findsOneWidget);
    });

    // Harm: the wrong change is secured, or against a state the project admin did not see.
    testWidgets('adding a member offers trusted people not yet in it, against what was read', (tester) async {
      final fixture = await _page(tester, 'pat');
      await pressOrganizationAction(tester, 'addMember');
      await tester.tap(find.byKey(const Key('organization-person')));
      await tester.pumpAndSettle();
      Finder offered(String login) => find.widgetWithText(DropdownMenuItem<String>, login);
      expect(offered('hana'), findsWidgets);
      for (final login in ['pat', 'mia', 'nora', 'rex']) {
        expect(offered(login), findsNothing, reason: login);
      }
      await tester.tap(find.text('hana').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      final write = fixture.writes.single;
      expect(write.change, OrganizationChange.addProjectMember);
      expect(write.input, {'project': 'demo', 'login': 'hana', 'role': 'developer'});
      expect(write.base, 'p1');
      expect(write.person, 'pat');
    });

    testWidgets('removing a member asks first, and only then writes', (tester) async {
      final fixture = await _page(tester, 'pat');
      await pressOrganizationAction(tester, 'removeMember/mia');
      expect(fixture.writes, isEmpty);
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.change, OrganizationChange.removeProjectMember);
      expect(fixture.writes.single.input, {'project': 'demo', 'login': 'mia'});
    });

    // Harm: a role chosen in the menu is shown as granted before the source confirms it.
    testWidgets('a change of role asks the store and shows what it read back, not what was chosen', (tester) async {
      final fixture = await _page(tester, 'pat');
      await pressOrganizationAction(tester, 'memberRole/mia');
      await tester.tap(find.byKey(const Key('organization-member-role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('admin').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.change, OrganizationChange.changeProjectMemberRole);
      expect(fixture.writes.single.input, {'project': 'demo', 'login': 'mia', 'role': 'admin'});
      expect(fixture.writes.single.base, 'p1');
      final row = find.byKey(const ValueKey('mia'));
      expect(
        find.descendant(of: row, matching: find.text('developer')),
        findsOneWidget,
        reason: 'The store still answers developer.',
      );
    });

    // Harm: a confirm greyed with the dialog already filled, and nothing says what it waits for.
    testWidgets('the dialog of a role says another must be chosen', (tester) async {
      await _page(tester, 'pat');
      await pressOrganizationAction(tester, 'memberRole/pat');
      await tester.pumpAndSettle();
      expect(find.textContaining('Choose a role other than'), findsOneWidget);
    });

    // Harm: a refused role change loses its refusal when the menu closes.
    testWidgets("a refused change of role says the store's words in its dialog", (tester) async {
      final fixture = await _page(tester, 'pat');
      fixture.refuseNext = const OrganizationRefused('The project moved on; read it again.');
      await pressOrganizationAction(tester, 'memberRole/mia');
      await tester.tap(find.byKey(const Key('organization-member-role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('admin').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('The project moved on; read it again.'), findsOneWidget);
    });

    // Harm: an admin cannot see that one repository lets work leave the gate unreviewed while the project requires review.
    testWidgets('the policy of the project and of each repository is shown', (tester) async {
      await _page(
        tester,
        'mia',
        project: const ProjectView(
          name: 'demo',
          revision: 'p1',
          review: 'required',
          repositories: [
            ProjectRepository(name: 'app', address: 'git@forge.example.org:acme/app.git', review: 'optional'),
            ProjectRepository(name: 'docs', address: 'git@forge.example.org:acme/docs.git', review: 'required'),
          ],
        ),
      );
      expect(find.text('Review is required.'), findsOneWidget);
      expect(find.text('git@forge.example.org:acme/app.git · Review is optional.'), findsOneWidget);
      expect(find.text('git@forge.example.org:acme/docs.git · Review is required.'), findsOneWidget);
      expect(find.textContaining('does not name'), findsNothing);
    });

    // Harm: repositories added before a machine are taken by no host, with no refusal: the foo test's order.
    testWidgets('on a project on no machine, the address is its central too', (tester) async {
      final fixture = FixtureOrganization(
        organizationFor(
          'pat',
          host: const OrganizationHost(name: 'build', admins: ['pat'], projects: ['demo']),
        ),
      )..projects = {'demo': demoProject};
      final organization = Organization(fixture);
      addTearDown(organization.dispose);
      await organization.refresh();
      await _settle(tester, OrganizationProjectPage(organization: organization, project: 'demo', onBack: () {}));
      await pressOrganizationAction(tester, 'addRepository');
      await tester.enterText(find.byKey(const Key('organization-repository-name')), 'site');
      await tester.enterText(
        find.byKey(const Key('organization-repository-address')),
        'git@forge.example.org:acme/s.git',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.input['address'], 'git@forge.example.org:acme/s.git');
      expect(fixture.writes.single.input['central'], 'git@forge.example.org:acme/s.git');
    });

    // Harm: a new repository could lose its required review policy when its signed write is assembled.
    testWidgets('adding a repository names it and its address', (tester) async {
      final fixture = await _page(tester, 'pat');
      await pressOrganizationAction(tester, 'addRepository');
      await tester.enterText(find.byKey(const Key('organization-repository-name')), 'demo-site');
      await tester.enterText(
        find.byKey(const Key('organization-repository-address')),
        'git@forge.example.org:acme/s.git',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.change, OrganizationChange.addProjectRepository);
      expect(fixture.writes.single.input, {
        'project': 'demo',
        'repository': 'demo-site',
        'address': 'http://127.0.0.1:8082/demo/s.git',
        'central': 'git@forge.example.org:acme/s.git',
        'review': 'required',
      });
    });

    // Harm: a token pasted into an address reaches the organization, where everyone reads it.
    testWidgets('an address with a token is refused before the store is asked, without repeating it', (tester) async {
      final fixture = await _page(tester, 'pat');
      await pressOrganizationAction(tester, 'addRepository');
      await tester.enterText(find.byKey(const Key('organization-repository-name')), 'demo-site');
      await tester.enterText(
        find.byKey(const Key('organization-repository-address')),
        'https://sekret-token@forge.example.org/acme/s.git',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes, isEmpty);
      expect(find.textContaining('without a user name, password or token'), findsOneWidget);
    });

    testWidgets('the project repository is read by everyone and changed by its project admin', (tester) async {
      final fixture = await _page(tester, 'pat');
      expect(find.text('Project repository: git@forge.example.org:acme/demo-project.git'), findsOneWidget);
      await pressOrganizationAction(tester, 'changeAddress');
      await tester.enterText(
        find.byKey(const Key('organization-project-address')),
        'git@forge.example.org:acme/new.git',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.change, OrganizationChange.changeProjectRepository);
      expect(fixture.writes.single.input, {'project': 'demo', 'address': 'git@forge.example.org:acme/new.git'});
      expect(fixture.writes.single.base, 'p1');
    });

    testWidgets('a project with no address says so', (tester) async {
      await _page(
        tester,
        'mia',
        project: const ProjectView(name: 'demo', revision: 'p1'),
      );
      expect(find.text('Project repository: none named yet'), findsOneWidget);
    });

    // Harm: a token pasted into the project repository's address reaches the card, where everyone reads it.
    testWidgets('the project repository takes no address with a token', (tester) async {
      final fixture = await _page(tester, 'pat');
      await pressOrganizationAction(tester, 'changeAddress');
      await tester.enterText(
        find.byKey(const Key('organization-project-address')),
        'https://sekret@forge.example.org/a.git',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes, isEmpty);
      expect(find.textContaining('without a user name, password or token'), findsOneWidget);
    });

    testWidgets('removing a repository says it stays where it is', (tester) async {
      final fixture = await _page(tester, 'pat');
      await pressOrganizationAction(tester, 'removeRepository/demo-docs');
      expect(find.textContaining('stays where it is'), findsOneWidget);
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.writes.single.input, {'project': 'demo', 'repository': 'demo-docs'});
    });

    // Harm: an older Porelo removed it itself, and the page goes on listing it as if it had not.
    testWidgets('a repository an older Porelo removed itself is gone from the page', (tester) async {
      final fixture = await _page(tester, 'pat');
      fixture
        ..writesProjectFiles = true
        ..projects = {
          'demo': const ProjectView(name: 'demo', revision: 'p2', roles: ['developer']),
        };
      await pressOrganizationAction(tester, 'removeRepository/demo-docs');
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('demo-docs'), findsNothing);
    });

    // Harm: the entry for a name no longer typed is shown, and copied, beside the new one.
    testWidgets('an entry asked for before the last edit is not shown', (tester) async {
      final fixture = await _page(tester, 'pat');
      await pressOrganizationAction(tester, 'addRepository');
      await tester.enterText(find.byKey(const Key('organization-repository-name')), 'first');
      await tester.enterText(
        find.byKey(const Key('organization-repository-address')),
        'https://forge.example.org/f.git',
      );
      await tester.pumpAndSettle();
      final held = Completer<void>();
      fixture.holdWrites = held.future;
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('organization-repository-name')), 'second');
      held.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('project-file-entry')), findsNothing);
    });

    // Harm: a write asked for a project-file change swallows the entry and says nothing changed for an unknown reason.
    testWidgets('a write is never asked for a project-file change', (tester) async {
      final fixture = await _page(tester, 'pat');
      final organization = Organization(fixture);
      addTearDown(organization.dispose);
      await organization.refresh();
      final said = await organization.write(OrganizationChange.removeProjectRepository, {
        'project': 'demo',
        'repository': 'demo-docs',
      });
      expect(said, contains('entry'));
      expect(fixture.writes, isEmpty);
    });

    // Harm: a repository looks removed while the project file, which Porelo does not change, still holds it.
    testWidgets('a repository asked to be removed stays listed until its entry is committed', (tester) async {
      final fixture = await _page(tester, 'pat');
      await pressOrganizationAction(tester, 'removeRepository/demo-docs');
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('take the entry out'), findsOneWidget);
      expect(find.byKey(const Key('copy-project-file-entry')), findsNothing, reason: 'There is nothing to copy.');
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('demo-docs'), findsOneWidget);
      expect(fixture.writes, hasLength(1));
    });

    // Harm: a project nobody opened reads as an empty one, or only its project admin's key could open it and another tries.
    group('not opened yet', () {
      const fresh = ProjectView(
        name: 'demo',
        revision: 'p1',
        opened: false,
        members: [ProjectMember(login: 'pat', role: 'admin', standing: CardStanding.trusted)],
      );

      testWidgets('says so to whoever reaches its page, and goes back', (tester) async {
        await _page(tester, 'pat', project: fresh);
        expect(find.textContaining('demo has no Git repository yet.'), findsOneWidget);
        expect(find.textContaining('Porelo does not name'), findsNothing);
        expect(find.textContaining('none named yet'), findsNothing);
        expect(find.byKey(const ValueKey('organization.backFromProject')), findsOneWidget);
      });

      testWidgets('a project with its repository does not say it has none', (tester) async {
        await _page(tester, 'pat');
        expect(find.textContaining('no Git repository yet'), findsNothing);
      });
    });

    testWidgets('a project the store does not have says so', (tester) async {
      final fixture = FixtureOrganization(organizationFor('mia'))..projects = {};
      final organization = Organization(fixture);
      addTearDown(organization.dispose);
      await _settle(tester, OrganizationProjectPage(organization: organization, project: 'demo', onBack: () {}));
      expect(find.text('There is no project demo.'), findsOneWidget);
    });
  });

  group('what the reading of these pages found', () {
    const member = ProjectMember(login: 'pat', role: 'admin', standing: CardStanding.trusted);
    const locked = ProjectMember(login: 'pat', role: 'admin', standing: CardStanding.trusted, locked: true);
    const revoked = ProjectMember(login: 'pat', role: 'admin', standing: CardStanding.revoked);

    Future<void> opened(WidgetTester tester, ProjectView view, {String me = 'pat'}) async {
      final organization = Organization(FixtureOrganization(organizationFor(me))..projects = {'demo': view});
      addTearDown(organization.dispose);
      await organization.refresh();
      await _settle(tester, OrganizationProjectPage(organization: organization, project: 'demo', onBack: () {}));
    }

    ProjectView withMe(ProjectMember me, {bool opened = true}) => ProjectView(
      name: 'demo',
      revision: 'p1',
      host: 'build',
      opened: opened,
      roles: const ['developer', 'admin'],
      members: [me],
    );

    // Harm: a member whose card the project answers as revoked is offered every change.
    testWidgets('an admin whose card is revoked changes nothing', (tester) async {
      await opened(tester, withMe(revoked));
      expect(_action('changeAddress'), findsNothing);
      expect(_action('addMember'), findsNothing);
    });

    // Harm: a locked member, who may do nothing, is called its admin.
    testWidgets('a locked admin is said to be locked', (tester) async {
      await opened(tester, withMe(locked));
      expect(find.text('Project Admin'), findsNothing);
      expect(find.text('locked'), findsNWidgets(2), reason: 'on the chip and on the row');
    });

    // Harm: changes are written to a project whose project.yml does not exist yet.
    testWidgets('a project with no repository yet offers nothing on its page', (tester) async {
      await opened(tester, withMe(member, opened: false));
      expect(_action('changeAddress'), findsNothing);
      expect(_action('addRepository'), findsNothing);
      expect(_action('addMember'), findsNothing);
    });

    // Harm: a member is added with no role, which the store cannot read.
    testWidgets('a project naming no roles offers no member to add', (tester) async {
      await opened(tester, const ProjectView(name: 'demo', revision: 'p1', members: [member]));
      expect(tester.widget<OutlinedButton>(_action('addMember')).onPressed, isNull);
    });

    // Harm: the store's refusal is lost, with the dialog closed while the change was still being asked for.
    testWidgets('a dialog stays open while its change is being asked for', (tester) async {
      final fixture = FixtureOrganization(organizationFor('pat'))..projects = {'demo': withMe(member)};
      final answer = Completer<void>();
      fixture.holdWrites = answer.future;
      final organization = Organization(fixture);
      addTearDown(organization.dispose);
      await organization.refresh();
      await _settle(tester, OrganizationProjectPage(organization: organization, project: 'demo', onBack: () {}));
      await pressOrganizationAction(tester, 'changeAddress');
      await tester.enterText(find.byType(TextField).first, 'git@forge.example.org:acme/moved.git');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(const Key('organization-confirm')), findsOneWidget);
      answer.complete();
      await tester.pumpAndSettle();
    });
  });

  group("a project's page and its machine", () {
    Future<FixtureOrganization> onPage(WidgetTester tester, {String? host}) async {
      final view = organizationFor(
        'olive',
        moreProjects: [
          OrganizationProject(name: 'mine', admins: const ['olive'], host: host),
        ],
      );
      final fixture = FixtureOrganization(view)
        ..projects = {
          'mine': ProjectView(
            name: 'mine',
            revision: 'p1',
            host: host,
            members: const [ProjectMember(login: 'olive', role: 'admin', standing: CardStanding.trusted)],
          ),
        };
      final organization = Organization(fixture);
      addTearDown(organization.dispose);
      await organization.refresh();
      await _settle(tester, OrganizationProjectPage(organization: organization, project: 'mine', onBack: () {}));
      return fixture;
    }

    Future<void> press(WidgetTester tester, String id) async {
      await _tap(
        tester,
        find.byWidgetPredicate((widget) => widget is CommandMenu && widget.commands.any((each) => each.id == id)),
      );
      await _tap(tester, find.byKey(ValueKey<String>(id)));
    }

    // Harm: the action is missing from the page a person opens the project on.
    testWidgets('a project on no machine is put on one the person administers', (tester) async {
      final fixture = await onPage(tester);
      await press(tester, 'project.putOnMachine');
      await _tap(tester, find.byKey(const Key('organization-person')));
      await _tap(tester, find.text('spare').hitTestable());
      await _tap(tester, find.byKey(const Key('organization-confirm')));
      expect(fixture.writes.single.change, OrganizationChange.addProjectToHost);
      expect(fixture.writes.single.input, {'host': 'spare', 'project': 'mine'});
    });

    // Harm: a project is taken off a machine other than the one carrying it.
    testWidgets('a project on a machine is taken off that machine, after asking', (tester) async {
      final fixture = await onPage(tester, host: 'spare');
      expect(
        find.byWidgetPredicate(
          (widget) => widget is CommandMenu && widget.commands.any((each) => each.id == 'project.putOnMachine'),
        ),
        findsNothing,
      );
      await press(tester, 'project.takeOffMachine');
      expect(fixture.writes, isEmpty);
      await _tap(tester, find.byKey(const Key('organization-confirm')));
      expect(fixture.writes.single.change, OrganizationChange.removeProjectFromHost);
      expect(fixture.writes.single.input, {'host': 'spare', 'project': 'mine'});
    });
  });
}
