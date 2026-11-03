import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/ui/organization_page.dart';
import 'package:porelo_frontend/src/ui/organization_project_pages.dart';
import 'package:porelo_frontend/src/ui/pick_a_file.dart';
import 'package:porelo_frontend/src/ui/project_init_dialog.dart';

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';
import 'organization_actions.dart';

ProjectInitDraft _draft({String? revision = 'preview-base'}) => ProjectInitDraft(
  repository: 'app',
  upstream: null,
  draft: 'review: required\n',
  revision: revision,
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
  Future<ProjectInitDraft> Function()? preview;

  @override
  Future<ProjectInitDraft> readProjectInit(String checkout, {String? project, String? name}) async {
    previews.add((checkout: checkout, project: project));
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

  // Harm: canceling a native picker or confirming while a preview is incomplete must never sign anything.
  testWidgets('canceling a folder choice and waiting for a preview leave signing disabled', (tester) async {
    final source = _Source('pat');
    await _dialog(tester, source, pick: ({initialDirectory, title}) async => null);
    expect(source.previews, isEmpty);
    expect(tester.widget<FilledButton>(find.byKey(const Key('organization-confirm'))).onPressed, isNull);
    expect(source.writes, isEmpty);
    await tester.tap(find.text('Cancel'));
    await World.settle(tester);
    final reading = Completer<ProjectInitDraft>();
    source.preview = () => reading.future;
    await _dialog(tester, source);
    expect(tester.widget<FilledButton>(find.byKey(const Key('organization-confirm'))).onPressed, isNull);
    expect(source.writes, isEmpty);
    reading.complete(_draft());
    await World.settle(tester);
    expect(tester.widget<FilledButton>(find.byKey(const Key('organization-confirm'))).onPressed, isNotNull);
  });

  // Harm: malformed input or a missing revision could bypass review and sign against an unseen state.
  testWidgets('an unreadable draft or a draft with no revision cannot be signed', (tester) async {
    final source = _Source('pat')..preview = () async => throw const OrganizationRefused('Unreadable JSON.');
    await _dialog(tester, source);
    expect(find.textContaining('cannot say what to sign'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('organization-confirm'))).onPressed, isNull);
    await tester.tap(find.text('Cancel'));
    await World.settle(tester);
    source.preview = () async => _draft(revision: null);
    await _dialog(tester, source);
    expect(find.textContaining('names no project revision'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('organization-confirm'))).onPressed, isNull);
    expect(source.writes, isEmpty);
  });

  // Harm: a lost signing answer followed by Retry could create two commits or use an unreviewed revision.
  testWidgets('warnings precede signing and an uncertain retry keeps its base and ID', (tester) async {
    final source = _Source('pat')..refuseNext = const OrganizationRefused('No answer came.', answered: false);
    await _dialog(tester, source);
    expect(source.previews.single, (checkout: '/checkouts/app', project: 'demo'));
    expect(find.textContaining('verify or package'), findsOneWidget);
    expect(find.textContaining('Credentials needed: forge access'), findsOneWidget);
    expect(find.textContaining('No version found.'), findsOneWidget);
    expect(find.textContaining('pom.xml:7'), findsOneWidget);
    expect(find.textContaining('not detected'), findsOneWidget);
    expect(find.textContaining('build: mvn verify · unknown'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(source.writes, isEmpty);
    await _confirm(tester);
    expect(find.text('No answer came.'), findsOneWidget);
    await _confirm(tester);
    expect(source.writes, hasLength(2));
    expect(source.writes.first.change, OrganizationChange.initializeProject);
    expect(source.writes.first.input, {'project': 'demo', 'checkout': '/checkouts/app'});
    expect(source.writes.map((write) => write.base), everyElement('preview-base'));
    expect(source.writes.last.id, source.writes.first.id);
    expect(find.byType(ProjectInitDialog), findsNothing);
  });

  // Harm: retrying a refused stale draft could apply a new revision without showing the corresponding preview.
  testWidgets('a definitive moved-on refusal can be reopened with a fresh preview and a new change ID', (tester) async {
    final source = _Source('pat')..refuseNext = const OrganizationRefused('The project moved on.', reason: 'moved-on');
    final organization = await _dialog(tester, source);
    await _confirm(tester);
    expect(source.writes.single.base, 'preview-base');
    await tester.tap(find.text('Cancel'));
    await World.settle(tester);
    source.preview = () async => _draft(revision: 'fresh-base');
    await _dialog(tester, source, existing: organization);
    await _confirm(tester);
    expect(source.writes.last.base, 'fresh-base');
    expect(source.writes.last.id, isNot(source.writes.first.id));
    expect(source.previews, hasLength(2));
  });

  // Harm: enabling optional review without a Project Admin's signed choice lets work leave unchecked.
  testWidgets('opening defaults to required and a solo choice carries through to each new repository', (tester) async {
    final source = _Source('pat')
      ..projects = {
        'demo': const ProjectView(
          name: 'demo',
          revision: 'org-base',
          opened: false,
          members: [ProjectMember(login: 'pat', role: 'admin', standing: CardStanding.trusted)],
        ),
      };
    await _organization(
      tester,
      source,
      (organization) => OrganizationProjectPage(organization: organization, project: 'demo', onBack: () {}),
    );
    await pressOrganizationAction(tester, 'openProject', settle: () => World.settle(tester));
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('organization-work-alone'))).value, isFalse);
    await tester.tap(find.byKey(const Key('organization-work-alone')));
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
      expect(source.writes.last.input['review'], 'optional');
      expect(source.writes.last.base, 'file-after');
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
          'demo': ProjectView(
            name: 'demo',
            revision: 'org-base',
            repositoriesRevision: 'file-base',
            review: review,
            members: demoProject.members,
          ),
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
        expect(source.writes.single.base, 'file-base');
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
            repositoriesRevision: 'file-base',
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
      expect(source.writes.single.base, 'file-base');
    });
  }
}
