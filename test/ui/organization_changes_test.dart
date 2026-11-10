import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/ui/organization_project_pages.dart';
import 'package:porelo_frontend/src/ui/organization_dialogs.dart';
import 'package:porelo_frontend/src/ui/filtered_list_section.dart';

import '../support/organization_fixtures.dart';
import 'organization_actions.dart';

class _HeldReads extends FixtureOrganization {
  _HeldReads() : super(organizationFor('pat'));

  Completer<OrganizationView>? organizationAnswer;
  Completer<ProjectView>? projectAnswer;
  OrganizationRefused? projectFailure;
  int projectReads = 0;

  @override
  Future<OrganizationView> read() => organizationAnswer?.future ?? super.read();

  @override
  Future<ProjectView> readProject(String project) {
    projectReads++;
    if (projectFailure case final failure?) return Future<ProjectView>.error(failure);
    return projectAnswer?.future ?? super.readProject(project);
  }
}

void main() {
  // Harm: decorating a list with provisional changes hides a read refusal and strands its retry or return path.
  testWidgets('a decorated leaf keeps its read refusal, retry and ancestor link', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final organization = Organization(FixtureOrganization(organizationFor('pat')));
    addTearDown(organization.dispose);
    var retries = 0;
    var returns = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FilteredListSection(
              title: 'People',
              storageId: 'organization-people',
              leaf: true,
              path: [(label: 'Organization', go: () => returns++)],
              problem: 'The organization cannot be read.',
              onRetry: () => retries++,
              rows: const [(words: 'pat', child: Text('pat'))],
            ).withOrganizationChanges(organization, names: const ['pat']),
          ),
        ),
      ),
    );
    expect(find.text('The organization cannot be read.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retries, 1, reason: 'the decorated list must retain the actual retry');
    await tester.tap(find.widgetWithText(TextButton, 'Organization'));
    expect(returns, 1, reason: 'the decorated list must retain its ancestor navigation');
  });

  // Harm: closing a slow change loses its refusal, permits a competing write, or retries an unanswered write twice.
  testWidgets('a provisional member survives navigation and retries safely through both rereads', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = _HeldReads();
    final organization = Organization(source);
    addTearDown(organization.dispose);
    await organization.refresh();

    Future<void> page() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrganizationProjectPage(organization: organization, project: 'demo', onBack: () {}),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> leave() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    final pending = find.byKey(const ValueKey('organization-pending project-members demo hana'));
    final running = find.byKey(const Key('organization-change-running'));
    await page();
    await tester.pumpAndSettle();
    await pressOrganizationAction(tester, 'addMember');
    await tester.tap(find.byKey(const Key('organization-person')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('hana').last);
    await tester.pumpAndSettle();

    final writing = Completer<void>();
    source.holdWrites = writing.future;
    source.refuseNext = const OrganizationRefused('No answer from the forge.', answered: false);
    await tester.tap(find.byKey(const Key('organization-confirm')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlertDialog), findsNothing, reason: 'The change continues in its provisional row.');
    expect(pending, findsOneWidget);
    expect(running, findsOneWidget);

    await leave();
    await page();
    expect(pending, findsOneWidget, reason: 'Leaving the page cannot abandon a request.');
    final organizationAnswer = Completer<OrganizationView>();
    source.organizationAnswer = organizationAnswer;
    writing.complete();
    await tester.pump();
    final readsBefore = source.projectReads;
    final projectAnswer = Completer<ProjectView>();
    source.projectAnswer = projectAnswer;
    organizationAnswer.complete(organizationFor('pat'));
    await tester.pump();
    expect(source.projectReads, readsBefore + 1, reason: 'The project read still follows the organization read.');
    expect(pending, findsOneWidget);
    expect(running, findsOneWidget, reason: 'The last read is still part of the change.');
    await organization.write(OrganizationChange.removeProjectMember, {'project': 'demo', 'login': 'mia'});
    expect(source.writes, hasLength(1), reason: 'A competing write cannot use the old revision.');
    projectAnswer.complete(demoProject);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('No answer from the forge.'), findsOneWidget);

    source.organizationAnswer = null;
    source.projectAnswer = null;
    await leave();
    source.projectFailure = const OrganizationRefused('The project cannot be read.');
    await page();
    await tester.pumpAndSettle();
    expect(find.text('No answer from the forge.'), findsOneWidget, reason: 'The refusal belongs to the request.');
    // The page shows the last read beside it, whose sections say it too.
    expect(find.text('The project cannot be read.'), findsWidgets);
    source.projectFailure = null;
    final retry = Completer<void>();
    source.holdWrites = retry.future;
    await pressOrganizationAction(
      tester,
      'retryChange/project-members demo/hana',
      // The running row turns for as long as the write is held, so nothing settles.
      settle: () async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
    await tester.pump(const Duration(seconds: 1));
    retry.complete();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(source.writes, hasLength(2));
    expect(source.writes.last.id, source.writes.first.id, reason: 'An unanswered write must not be applied twice.');
    expect(source.writes.last.base, source.writes.first.base);
    expect(pending, findsNothing);
    expect(
      find.byKey(const ValueKey('hana')),
      findsNothing,
      reason: 'A completed request cannot invent a member absent from the source answer.',
    );

    final removed = Completer<void>();
    source.holdWrites = removed.future;
    source.refuseNext = const OrganizationRefused('The project moved on.', reason: 'moved-on');
    await pressOrganizationAction(tester, 'removeMember/mia');
    await tester.tap(find.byKey(const Key('organization-confirm')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await leave();
    removed.complete();
    await tester.pump();
    source.projectFailure = const OrganizationRefused('The project cannot be read.');
    await page();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('organization-pending project-members demo mia')),
      findsOneWidget,
      reason: 'A refused removal stays reachable even if reopening the project fails.',
    );
    final writesBefore = source.writes.length;
    await pressOrganizationAction(tester, 'retryChange/project-members demo/mia');
    expect(source.writes, hasLength(writesBefore), reason: 'An answered refusal needs a fresh revision first.');
    // A disabled retry keeps its menu open.
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    source.projectFailure = null;
    source.projects = {
      'demo': ProjectView(
        name: 'demo',
        revision: 'p2',
        repositories: demoProject.repositories,
        members: demoProject.members,
        roles: demoProject.roles,
      ),
    };
    await pressOrganizationAction(tester, 'reviewChange/project-members demo/mia');
    source.holdWrites = null;
    await pressOrganizationAction(tester, 'retryChange/project-members demo/mia');
    expect(source.writes.last.base, 'p2', reason: 'A new attempt uses the revision the person has just reviewed.');
    expect(
      source.writes.last.id,
      isNot(source.writes[writesBefore - 1].id),
      reason: 'An answered request is followed by a new attempt.',
    );
  });
}
