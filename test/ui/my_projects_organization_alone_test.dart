import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../features/support/world.dart';
import '../features/support/tiles.dart' show leafPageTitle;
import '../support/organization_fixtures.dart';

void main() {
  // Harm: My projects lists what a start in a checkout copied and the project every machine has as if they were the
  // organization's, as the operator found with two local copies, and the rail counts them too.
  testWidgets('My projects lists the organization\'s projects alone, and the rest stands with every machine\'s', (
    tester,
  ) async {
    await World.startBackend(World.work);
    final source = FixtureOrganization(organizationFor('pat'))
      ..listed = const [ListedProject(name: 'units4j-project', source: 'local')];
    await World.startApp(tester, organizationSource: source);
    World.shell.goTo(Section.projects);
    await World.settle(tester);
    expect(find.byKey(const Key('organization-projects-page')), findsOneWidget);
    final row = ValueKey<String>('project ${World.machines.current.name}/$defaultProject');
    expect(find.byKey(row), findsNothing, reason: 'Default is no project of the organization');
    expect(find.byKey(const ValueKey('my-project units4j-project')), findsNothing, reason: 'nor is a local copy');
    expect(find.text('only on this computer'), findsNothing);
    expect(
      find.descendant(of: find.byKey(const ValueKey<String>('rail projects')), matching: find.text('1')),
      findsOneWidget,
      reason: 'the one of the organization, on the rail as on the page',
    );
    await tester.tap(find.byKey(const Key('projects-of-machines')));
    await World.settle(tester);
    expect(leafPageTitle('Projects on my machines'), findsOneWidget);
    expect(find.byKey(row), findsOneWidget, reason: 'Default stands with every machine\'s projects');
    expect(find.widgetWithText(TextButton, 'My projects'), findsOneWidget);
  });
}
