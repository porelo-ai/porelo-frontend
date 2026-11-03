import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/ui/organization_project_pages.dart';

import '../support/organization_fixtures.dart';

import 'package:porelo_frontend/src/ui/command_menu.dart';

import 'organization_actions.dart';

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

void main() {
  // Harm: a locked member takes their project for one they can work on; a local project cannot be found from here.
  testWidgets('the list says who is locked, and a project of this computer alone leads to the machines', (
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
    await tester.tap(find.byKey(const ValueKey('my-project mine')));
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

    // Harm: a person cannot get from a project to where work on it starts.
    testWidgets('a row opens its project on its one host', (tester) async {
      final organization = Organization(FixtureOrganization(organizationFor('pat')));
      addTearDown(organization.dispose);
      final opened = <(String, String)>[];
      await _settle(
        tester,
        OrganizationProjectsPage(
          organization: organization,
          onProject: (_) {},
          onHost: (project, host) => opened.add((project, host)),
        ),
      );
      await pressOrganizationAction(tester, 'openOnHost demo');
      expect(opened, [('demo', 'build')]);
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
      expect(find.text('2 repositories · 2 people · on build'), findsOneWidget);
      expect(find.text('project admin'), findsOneWidget);
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
      expect(find.textContaining('a project admin adds you'), findsOneWidget);
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
        expect(find.text('Project admin pat. Only they change this project.'), findsOneWidget);
        expect(find.text('demo-docs'), findsOneWidget);
        expect(find.text('git@forge.example.org:acme/demo-docs.git'), findsOneWidget);
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

    testWidgets('a change of role asks the store and shows what it read back, not what was chosen', (tester) async {
      final fixture = await _page(tester, 'pat');
      await pressOrganizationAction(tester, 'memberRole/mia');
      await tester.tap(find.text('admin').last);
      await tester.pumpAndSettle();
      expect(fixture.writes.single.change, OrganizationChange.changeProjectMemberRole);
      expect(fixture.writes.single.input, {'project': 'demo', 'login': 'mia', 'role': 'admin'});
      expect(fixture.writes.single.base, 'p1');
      final role = tester.widget<DropdownButton<String>>(_action('memberRole/mia'));
      expect(role.value, 'developer', reason: 'The store still answers developer.');
    });

    testWidgets("a refused change of role says the store's words in the row", (tester) async {
      final fixture = await _page(tester, 'pat');
      fixture.refuseNext = const OrganizationRefused('The project moved on; read it again.');
      await pressOrganizationAction(tester, 'memberRole/mia');
      await tester.tap(find.text('admin').last);
      await tester.pumpAndSettle();
      expect(find.text('The project moved on; read it again.'), findsOneWidget);
    });

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
        'address': 'git@forge.example.org:acme/s.git',
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

    testWidgets('what the store reads after a change is shown', (tester) async {
      final fixture = await _page(tester, 'pat');
      fixture.afterWrite = (_) {
        fixture.projects = {
          'demo': const ProjectView(name: 'demo', revision: 'p2', roles: ['developer']),
        };
        return fixture.view;
      };
      await pressOrganizationAction(tester, 'removeRepository/demo-docs');
      await tester.tap(find.byKey(const Key('organization-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('demo-docs'), findsNothing);
    });

    // Harm: a project nobody opened reads as an empty one, or only its project admin's key could open it and another tries.
    group('not opened yet', () {
      const fresh = ProjectView(
        name: 'demo',
        revision: 'p1',
        opened: false,
        members: [ProjectMember(login: 'pat', role: 'admin', standing: CardStanding.trusted)],
      );

      testWidgets('its project admin opens it, and is asked to confirm', (tester) async {
        final fixture = await _page(tester, 'pat', project: fresh);
        await pressOrganizationAction(tester, 'openProject');
        expect(fixture.writes, isEmpty);
        await tester.tap(find.byKey(const Key('organization-confirm')));
        await tester.pumpAndSettle();
        expect(fixture.writes.single.change, OrganizationChange.openProject);
        expect(fixture.writes.single.input, {'project': 'demo'});
        expect(fixture.writes.single.base, 'p1');
      });

      testWidgets('anyone else reads that it is not open and has no way to open it', (tester) async {
        await _page(tester, 'mia', project: fresh);
        expect(_action('openProject'), findsNothing);
        expect(find.text('pat has not opened this project yet.'), findsOneWidget);
      });

      testWidgets('an opened project offers no opening', (tester) async {
        await _page(tester, 'pat');
        expect(_action('openProject'), findsNothing);
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
      expect(find.text('project admin'), findsNothing);
      expect(find.text('locked'), findsNWidgets(2), reason: 'on the chip and on the row');
    });

    // Harm: changes are written to a project whose project.yml does not exist yet.
    testWidgets('a project not opened yet offers its admin nothing but opening it', (tester) async {
      await opened(tester, withMe(member, opened: false));
      expect(_action('openProject'), findsOneWidget);
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
}
