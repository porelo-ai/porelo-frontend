import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/ui/organization_dialogs.dart';
import 'package:porelo_frontend/src/ui/organization_page.dart';
import 'package:porelo_frontend/src/ui/organization_project_pages.dart';
import 'package:porelo_frontend/src/ui/pick_a_file.dart';
import 'package:porelo_frontend/src/ui/project_init_dialog.dart';

import 'package:porelo_frontend/src/app/commands.dart';

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';
import 'organization_actions.dart';

const _entry = 'repositories:\n  app: {}\n';

ProjectInitDraft _draft({String? entry = _entry}) => ProjectInitDraft(
  repository: 'app',
  upstream: null,
  draft: 'review: required\n',
  revision: null,
  entry: entry,
  values: const [
    ProjectInitValue(
      key: 'build',
      value: 'mvn verify',
      unknown: true,
      file: 'pom.xml',
      line: 7,
      note: 'Check the profile.',
    ),
    ProjectInitValue(key: 'agent', value: 'unknown', unknown: true, origin: 'not detected'),
  ],
  disagreements: const [(key: 'build', values: 'verify or package')],
  unplaced: 'custom setting',
  notPlaced: 'unsupported setting',
  credentialsNeeded: 'forge access',
  plugins: const [(name: 'maven', state: 'cannot-say', why: 'No version found.')],
);

class _Source extends FixtureOrganization {
  _Source(String me) : super(organizationFor(me));

  final previews = <({String checkout, String? project})>[];
  final upstreams = <String?>[];
  Future<ProjectInitDraft> Function()? preview;

  @override
  Future<ProjectInitDraft> readProjectInit(String checkout, {String? project, String? name, String? upstream}) async {
    previews.add((checkout: checkout, project: project));
    upstreams.add(upstream);
    return preview == null ? _draft() : await preview!();
  }
}

Future<Organization> _organization(WidgetTester tester, _Source source, Widget Function(Organization) page) async {
  tester.view.physicalSize = const Size(1280, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final organization = Organization(source);
  addTearDown(organization.dispose);
  await organization.refresh();
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page(organization))));
  await World.settle(tester);
  return organization;
}

Future<Organization> _dialog(WidgetTester tester, _Source source, {PickAFolder? pick, Organization? existing}) async {
  final organization = existing ?? await _organization(tester, source, (_) => const SizedBox.shrink());
  unawaited(
    showDialog<void>(
      context: tester.element(find.byType(Scaffold)),
      builder: (_) => ProjectInitDialog(
        organization: organization,
        project: 'demo',
        pickFolder: pick ?? ({initialDirectory, title}) async => '/checkouts/app',
      ),
    ),
  );
  await World.settle(tester);
  return organization;
}

Finder get _entryShown => find.byKey(const Key('project-file-entry'));

Future<void> _close(WidgetTester tester) async {
  await tester.tap(find.text('Close'));
  await World.settle(tester);
}

Future<void> _confirm(WidgetTester tester) async {
  final confirm = find.byKey(const Key('organization-confirm'));
  await tester.ensureVisible(confirm);
  await tester.tap(confirm);
  await World.settle(tester);
}

void main() {
  // Harm: a person without either admin role could start a signed project import.
  for (final (me, allowed) in [('olive', true), ('pat', true), ('mia', false), ('rex', false)]) {
    testWidgets('checkout import follows the admin roles for $me', (tester) async {
      final source = _Source(me);
      await _organization(tester, source, (organization) => OrganizationPage(organization: organization));
      expect(organizationAction('initializeProject/demo'), allowed ? findsOneWidget : findsNothing);
      expect(source.writes, isEmpty);
    });
  }

  // Harm: a person with no right on the machine is offered taking Porelo off it, or its admin on another computer is not.
  for (final (me, allowed) in [('hana', true), ('olive', true), ('mia', false)]) {
    testWidgets('taking Porelo off stands on the row for $me as the rights say', (tester) async {
      await _organization(
        tester,
        _Source(me),
        (organization) => OrganizationPage(
          organization: organization,
          takeOff: (host) =>
              organizationCommand(id: 'takeOff/${host.name}', label: 'Take Porelo off this machine…', run: () {}),
        ),
      );
      expect(organizationAction('takeOff/build'), allowed ? findsOneWidget : findsNothing);
    });
  }

  // Harm: the menu a machine's admin opens breaks, or one click starts taking Porelo off a machine twice.
  testWidgets('the row offers taking Porelo off once, and one click asks for it once', (tester) async {
    var asked = 0;
    await _organization(
      tester,
      _Source('hana'),
      (organization) => OrganizationPage(
        organization: organization,
        takeOff: (host) =>
            organizationCommand(id: 'takeOff/${host.name}', label: 'Take Porelo off this machine…', run: () => asked++),
      ),
    );
    final menu = organizationAction('takeOff/build');
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text('Take Porelo off this machine…'), findsOneWidget);
    await tester.tap(find.text('Take Porelo off this machine…'));
    await tester.pumpAndSettle();
    expect(asked, 1);
  });

  // Harm: a task on a machine reads the central forge, past the machine's gate, or what is signed differs from what was read.
  testWidgets('a project on a machine is read with the machine\'s own address, and its entry shown', (tester) async {
    final source = _Source('pat');
    await _dialog(tester, source);
    expect(source.upstreams, [null, 'http://127.0.0.1:8082/demo/app.git']);
    expect(find.text(_entry), findsOneWidget);
    expect(find.textContaining("project.yml in the own repository of project demo"), findsOneWidget);
    expect(source.writes, isEmpty);
  });

  // Harm: a person signs a security class and a project address the dialog never showed them.
  testWidgets('a draft that proposes an online project is shown as Core wrote it, and no word says guarded', (
    tester,
  ) async {
    const proposed =
        'project:\n  name: demo\n  security_class: online\n  upstream: "http://127.0.0.1:8082/demo/demo.git"\n';
    final source = _Source('pat')
      ..preview = () async => ProjectInitDraft(
        repository: 'app',
        upstream: 'http://127.0.0.1:8082/demo/app.git',
        draft: proposed,
        revision: null,
        entry: _entry,
        values: const [],
        disagreements: const [],
        unplaced: '',
        notPlaced: '',
        credentialsNeeded: '',
        plugins: const [],
      );
    await _dialog(tester, source);
    expect(find.text('Upstream: http://127.0.0.1:8082/demo/app.git'), findsOneWidget);
    expect(find.text(proposed), findsOneWidget);
    expect(find.textContaining('guarded'), findsNothing);
  });

  // Harm: a project on no machine gets an address nothing answers at.
  test('no machine, or no port on its card, names no local address', () {
    final view = organizationFor('pat');
    expect(view.localAddress('other', 'app'), isNull);
    final noPort = organizationFor(
      'pat',
      host: const OrganizationHost(name: 'build', admins: ['hana'], projects: ['demo']),
    );
    expect(noPort.localAddress('demo', 'app'), isNull);
    expect(
      view.localAddress('demo', 'git@forge.example.org:org/widgets.git'),
      'http://127.0.0.1:8082/demo/widgets.git',
    );
  });

  // Harm: a first project named as its repository meets Core's refusal with no way on, or is signed and refused later.
  testWidgets('a checkout named as the project shows no entry, and another name is offered', (tester) async {
    final source = _Source('pat');
    source.preview = () async => ProjectInitDraft(
      repository: 'demo',
      upstream: null,
      draft: 'review: required\n',
      revision: null,
      entry: _entry,
      values: const [],
      disagreements: const [],
      unplaced: '',
      notPlaced: '',
      credentialsNeeded: '',
      plugins: const [],
    );
    await _dialog(tester, source);
    await tester.tap(find.text('Choose a checkout folder…'));
    await World.settle(tester);
    expect(find.textContaining('demo-project'), findsOneWidget);
    expect(_entryShown, findsNothing);
    expect(source.writes, isEmpty);
  });

  // Harm: an entry is shown for a folder never read, or before its draft is complete.
  testWidgets('canceling a folder choice and waiting for a preview show no entry', (tester) async {
    final source = _Source('pat');
    await _dialog(tester, source, pick: ({initialDirectory, title}) async => null);
    expect(source.previews, isEmpty);
    expect(_entryShown, findsNothing);
    await _close(tester);
    final reading = Completer<ProjectInitDraft>();
    source.preview = () => reading.future;
    await _dialog(tester, source);
    expect(_entryShown, findsNothing);
    reading.complete(_draft());
    await World.settle(tester);
    expect(_entryShown, findsOneWidget);
    expect(source.writes, isEmpty);
  });

  // Harm: an unreadable draft, or one with no entry, leaves the person with nothing to commit and no word why.
  testWidgets('an unreadable draft or a draft with no entry says so, and shows none', (tester) async {
    final source = _Source('pat')..preview = () async => throw const OrganizationRefused('Unreadable JSON.');
    await _dialog(tester, source);
    expect(find.textContaining('cannot say the entry'), findsOneWidget);
    expect(_entryShown, findsNothing);
    await _close(tester);
    source.preview = () async => _draft(entry: null);
    await _dialog(tester, source);
    expect(find.textContaining('did not say the entry'), findsOneWidget);
    expect(_entryShown, findsNothing);
    expect(source.writes, isEmpty);
  });

  // Harm: the person commits an entry without the warnings Porelo found beside it, or the window signs something.
  testWidgets('warnings stand beside the entry, and nothing is signed or written', (tester) async {
    final source = _Source('pat');
    await _dialog(tester, source);
    expect(source.previews.first, (checkout: '/checkouts/app', project: 'demo'));
    expect(find.textContaining('verify or package'), findsOneWidget);
    expect(find.textContaining('Credentials needed: forge access'), findsOneWidget);
    expect(find.textContaining('No version found.'), findsOneWidget);
    expect(find.textContaining('pom.xml:7'), findsOneWidget);
    expect(find.textContaining('not detected'), findsOneWidget);
    expect(find.textContaining('build: mvn verify · unknown'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text(_entry), findsOneWidget);
    expect(find.byKey(const Key('organization-confirm')), findsNothing);
    expect(find.textContaining('Sign'), findsNothing);
    await _close(tester);
    expect(source.writes, isEmpty);
    expect(find.byType(ProjectInitDialog), findsNothing);
  });

  // Harm: enabling optional review without a Project Admin's signed choice lets work leave unchecked.
  testWidgets('a solo choice on creating its repository carries through to each new repository', (tester) async {
    Organization? made;
    final source = _Source('pat')
      ..projects = {
        'demo': const ProjectView(
          name: 'demo',
          revision: 'org-base',
          opened: false,
          members: [ProjectMember(login: 'pat', role: 'admin', standing: CardStanding.trusted)],
        ),
      };
    await _organization(tester, source, (organization) {
      made = organization;
      return OrganizationProjectPage(organization: organization, project: 'demo', onBack: () {});
    });
    unawaited(
      showDialog<void>(
        context: tester.element(find.byType(OrganizationProjectPage)),
        builder: (_) => CreateRepositoryDialog(made!, 'demo', base: 'org-base'),
      ),
    );
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('organization-review-optional')));
    await World.settle(tester);
    source.projects['demo'] = const ProjectView(
      name: 'demo',
      revision: 'org-after',
      repositoriesRevision: 'file-after',
      roles: ['developer', 'admin'],
      members: [ProjectMember(login: 'pat', role: 'admin', standing: CardStanding.trusted)],
    );
    await _confirm(tester);
    expect(source.writes.single.input['review'], 'optional');
    for (final name in ['first', 'second']) {
      await pressOrganizationAction(tester, 'addRepository', settle: () => World.settle(tester));
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('organization-repository-review'))).value, isFalse);
      await tester.enterText(find.byKey(const Key('organization-repository-name')), name);
      await tester.enterText(
        find.byKey(const Key('organization-repository-address')),
        'https://forge.example.org/$name.git',
      );
      await World.settle(tester);
      await _confirm(tester);
      expect(source.writes.last.change, OrganizationChange.addProjectRepository);
      expect(source.writes.last.input['review'], 'optional');
      expect(find.text('entry: addProjectRepository\n'), findsOneWidget);
      // Harm: a task reads central past the machine's gate, or Core refuses an address that ends otherwise.
      expect(source.writes.last.input['address'], 'http://127.0.0.1:8082/demo/$name.git');
      expect(source.writes.last.input['central'], 'https://forge.example.org/$name.git');
      await _close(tester);
    }
    expect(source.writes, hasLength(3));
  });

  // Harm: a member could weaken review, or a guessed current policy could conceal the action an admin needs.
  for (final (me, review, allowed) in [
    ('pat', null, true),
    ('pat', 'optional', true),
    ('mia', null, false),
    ('olive', null, false),
  ]) {
    testWidgets('review changes follow the Project Admin role and policy $review for $me', (tester) async {
      final source = _Source(me)
        ..projects = {
          'demo': ProjectView(name: 'demo', revision: 'org-base', review: review, members: demoProject.members),
        };
      await _organization(
        tester,
        source,
        (organization) => OrganizationProjectPage(organization: organization, project: 'demo', onBack: () {}),
      );
      expect(organizationAction('projectReview/required'), allowed ? findsOneWidget : findsNothing);
      expect(organizationAction('projectReview/optional'), allowed && review == null ? findsOneWidget : findsNothing);
      if (allowed) {
        await pressOrganizationAction(tester, 'projectReview/required', settle: () => World.settle(tester));
        expect(source.writes, isEmpty);
        await _confirm(tester);
        expect(source.writes.single.change, OrganizationChange.changeProjectReview);
        expect(source.writes.single.input, {'project': 'demo', 'review': 'required'});
        expect((source.writes.single.base, source.writes.single.id), ('', ''), reason: 'Nothing is signed.');
        expect(find.text('entry: changeProjectReview\n'), findsOneWidget);
      }
    });
  }

  // Harm: changing a project default cannot repair an explicit repository policy that still permits unchecked work.
  for (final policy in ['required', 'optional']) {
    testWidgets('an existing repository can have its own review policy changed to $policy', (tester) async {
      final source = _Source('pat')
        ..projects = {
          'demo': ProjectView(
            name: 'demo',
            revision: 'org-base',
            members: demoProject.members,
            repositories: demoProject.repositories,
          ),
        };
      await _organization(
        tester,
        source,
        (organization) => OrganizationProjectPage(organization: organization, project: 'demo', onBack: () {}),
      );
      await pressOrganizationAction(tester, 'repositoryReview/demo/$policy', settle: () => World.settle(tester));
      expect(source.writes, isEmpty);
      await _confirm(tester);
      expect(source.writes.single.change, OrganizationChange.changeProjectReview);
      expect(source.writes.single.input, {'project': 'demo', 'repository': 'demo', 'review': policy});
      expect(find.text('entry: changeProjectReview\n'), findsOneWidget);
    });
  }

  // Harm: offering a repository the policy it already has reads as if that policy did not hold.
  for (final review in ['required', 'optional', null]) {
    testWidgets('a repository with review $review offers only the policy it does not have', (tester) async {
      final source = _Source('pat')
        ..projects = {
          'demo': ProjectView(
            name: 'demo',
            revision: 'org-base',
            members: demoProject.members,
            repositories: [
              ProjectRepository(name: 'demo', address: demoProject.repositories.first.address, review: review),
            ],
          ),
        };
      await _organization(
        tester,
        source,
        (organization) => OrganizationProjectPage(organization: organization, project: 'demo', onBack: () {}),
      );
      for (final policy in ['required', 'optional']) {
        expect(
          organizationAction('repositoryReview/demo/$policy'),
          review == policy ? findsNothing : findsOneWidget,
          reason: 'a repository whose policy was not read offers both',
        );
      }
    });
  }
}
