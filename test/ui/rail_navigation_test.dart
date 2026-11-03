import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';

void main() {
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

      await tap('rail machines');
      await tap('my-host build');
      expect(find.byKey(const ValueKey('organization-host build')), findsOneWidget);
      if (leaveFirst) await tap('rail work');
      await tap('rail machines');
      expect(find.byKey(const ValueKey('my-host build')), findsOneWidget);
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
