import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';

void main() {
  // Harm: the project every machine has is found only behind a second page, while the list and the rail
  // count one project too few, as the operator found on a machine with one project of their organization.
  testWidgets('Default stands in My projects beside the organization\'s, and is counted', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester, organizationSource: FixtureOrganization(organizationFor('pat')));
    World.shell.goTo(Section.projects);
    await World.settle(tester);
    expect(find.byKey(const Key('organization-projects-page')), findsOneWidget);
    final row = ValueKey<String>('project ${World.machines.current.name}/$defaultProject');
    expect(find.byKey(row), findsOneWidget, reason: 'its row, with its words');
    expect(find.textContaining('always there'), findsOneWidget);
    expect(
      find.byKey(ValueKey<String>('projects-menu ${World.machines.current.name}/$defaultProject')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(const ValueKey<String>('rail projects')), matching: find.text('2')),
      findsOneWidget,
      reason: 'one of the organization and Default, on the rail as on the page',
    );
    await tester.tap(find.byKey(row));
    await World.settle(tester);
    expect(find.byKey(const Key('organization-projects-page')), findsNothing, reason: 'its page opens as any other');
  });
}
