import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_progress.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';

void main() {
  // Harm: a stale page hides restored access or changes to the repositories and people a project reaches.
  testWidgets('rail Refresh rereads the shown machine and project details without fetching the machine', (
    tester,
  ) async {
    final source = FixtureOrganization(organizationFor('hana'));
    final connections = FixtureConnections(['build'])
      ..hostProgress = const HostProgress(
        locked: [HostLockedPerson(login: 'rex', purgeOn: '2026-11-09')],
      );
    await World.startBackend(World.work);
    await World.startApp(tester, organizationSource: source, hostConnections: connections);
    await World.settings.setRefreshSeconds(1);
    await World.tapInView(tester, 'rail organization');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('my-host build')),
      200,
      scrollable: find
          .descendant(of: find.byKey(const Key('organization-page')), matching: find.byType(Scrollable))
          .first,
    );
    await World.tapInView(tester, 'my-host build');
    expect(find.byKey(const ValueKey('organization.locked/rex')), findsOneWidget);
    connections.asked.clear();
    connections.hostProgress = const HostProgress();

    await tester.pump(const Duration(seconds: 2));
    await World.settle(tester);
    expect(connections.asked, isEmpty, reason: 'automatic refresh leaves the machine status alone');
    expect(find.byKey(const ValueKey('organization.locked/rex')), findsOneWidget);
    await World.settings.setRefreshSeconds(0);
    await World.tapInView(tester, 'refresh-all');
    expect(connections.asked, ['progress build'], reason: 'the rail reads status without asking the machine to fetch');
    expect(find.byKey(const ValueKey('organization.locked/rex')), findsNothing);

    source.projects['other'] = const ProjectView(
      name: 'other',
      revision: 'p1',
      repositories: [ProjectRepository(name: 'before')],
      members: [ProjectMember(login: 'hana', role: 'admin', standing: CardStanding.trusted)],
    );
    await World.tapInView(tester, 'rail projects');
    await World.tapInView(tester, 'my-project other');
    expect(find.text('before'), findsOneWidget);
    source.projects['other'] = const ProjectView(
      name: 'other',
      revision: 'p2',
      repositories: [ProjectRepository(name: 'after')],
      members: [
        ProjectMember(login: 'hana', role: 'admin', standing: CardStanding.trusted),
        ProjectMember(login: 'mia', role: 'developer', standing: CardStanding.trusted),
      ],
    );
    await World.tapInView(tester, 'refresh-all');
    expect(find.text('after'), findsOneWidget);
    expect(find.text('before'), findsNothing);
    await World.reach(tester, find.text('mia'));
    expect(find.text('mia'), findsOneWidget);

    expect(source.writes, isEmpty);
  });

  // Harm: navigation strands a person in details or hides work behind a previous page's scope.
  testWidgets('rail entries return to their lists and Work shows every machine and project', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(
      tester,
      organizationSource: FixtureOrganization(organizationFor('mia')),
      hostConnections: FixtureConnections(),
    );

    Future<void> tap(String key) async {
      await World.tapInView(tester, key);
    }

    for (final leaveFirst in [false, true]) {
      await tap('rail projects');
      await tap('my-project demo');
      expect(find.byKey(const ValueKey('organization-project demo')), findsOneWidget);
      if (leaveFirst) await tap('rail work');
      await tap('rail projects');
      expect(find.byKey(const ValueKey('my-project demo')), findsOneWidget);
      expect(find.byKey(const ValueKey('organization-project demo')), findsNothing);

      await tap('projects-of-machines');
      expect(find.byKey(const Key('projects-of-organization')), findsOneWidget);
      if (leaveFirst) await tap('rail work');
      await tap('rail projects');
      expect(find.byKey(const ValueKey('my-project demo')), findsOneWidget);
      expect(find.byKey(const Key('projects-of-organization')), findsNothing);

      await tap('rail organization');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('my-host build')),
        200,
        scrollable: find
            .descendant(of: find.byKey(const Key('organization-page')), matching: find.byType(Scrollable))
            .first,
      );
      await tap('my-host build');
      expect(find.byKey(const ValueKey('organization-host build')), findsOneWidget);
      if (leaveFirst) await tap('rail work');
      await tap('rail machines');
      expect(find.byKey(const ValueKey('organization-host build')), findsNothing);
    }

    const second = Machine(name: 'elsewhere', socketPath: '/unused');
    await World.machines.add(second);
    await World.settle(tester);
    final machine = World.machines.current;
    final checkout = find.byKey(ValueKey('tile ${machine.name} porelo-checkout-shell'));
    final billing = find.byKey(ValueKey('tile ${machine.name} porelo-billing-shell'));
    final elsewhere = find.byKey(const ValueKey('tile elsewhere porelo-shared-shell'));

    for (final fromMachine in [false, true]) {
      if (fromMachine) {
        await tap('rail machines');
        await tap('tree-machine ${machine.name}');
        await tap('projects-menu ${machine.name}/checkout');
      } else {
        await tap('rail projects');
        await tap('projects-of-machines');
        await tap('project ${machine.name}/checkout');
        await tap('project-menu');
      }
      await tap('project.itsWork');
      expect(checkout, findsOneWidget, reason: 'the page link keeps its project and machine');
      expect(billing, findsNothing);
      expect(elsewhere, findsNothing);

      await tap('rail work');
      expect(checkout, findsOneWidget);
      expect(billing, findsOneWidget, reason: 'the rail restores work from other projects');
      expect(elsewhere, findsOneWidget, reason: 'the rail restores work from other machines');
    }
  });
}
