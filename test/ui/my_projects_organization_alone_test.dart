import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';

void main() {
  /// The rows *My projects* draws: the organization's, keyed by name, and each machine's, keyed by machine and name.
  Finder rows() => find.descendant(
    of: find.byKey(const Key('organization-projects-page')),
    matching: find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && (key.value.startsWith('my-project ') || key.value.startsWith('project '));
    }),
  );

  // Harm: with an organization, Default and a project only a machine holds stand on a second page the person must
  // find, the rail counts one list and the page another, and a local copy reads as the organization's.
  testWidgets('My projects is one list: the organization\'s, Default on each machine and each local project', (
    tester,
  ) async {
    await World.startBackend([...World.work, World.aTask('porelo-demo-shell', 'demo')]);
    await World.startApp(tester, organizationSource: FixtureOrganization(organizationFor('pat')));
    World.shell.goTo(Section.projects);
    await World.settle(tester);
    final machine = World.machines.current.name;

    expect(find.byKey(const ValueKey('my-project demo')), findsOneWidget, reason: 'the organization project, once');
    expect(
      find.byKey(ValueKey<String>('project $machine/demo')),
      findsNothing,
      reason: 'carried on a machine, the organization project stands in its own row, not a second time',
    );
    expect(find.byKey(ValueKey<String>('project $machine/$defaultProject')), findsOneWidget, reason: 'Default');
    final local = find.byKey(ValueKey<String>('project $machine/checkout'));
    expect(local, findsOneWidget, reason: 'a project only the machine holds');
    expect(
      find.descendant(of: local, matching: find.textContaining('local to $machine')),
      findsOneWidget,
      reason: 'marked as the machine\'s own, not the organization\'s',
    );
    expect(find.byKey(const Key('projects-of-machines')), findsNothing, reason: 'no second list to go to');

    final shown = rows().evaluate().length;
    expect(
      find.descendant(of: find.byKey(const ValueKey<String>('rail projects')), matching: find.text('$shown')),
      findsOneWidget,
      reason: 'the rail counts exactly the $shown rows shown',
    );
  });

  // Harm: an organization project the person holds no role in reads as one of theirs because a machine carries it.
  testWidgets('an organization project without a role stays off My projects, though a machine carries it', (
    tester,
  ) async {
    await World.startBackend([...World.work, World.aTask('porelo-other-shell', 'other')]);
    await World.startApp(tester, organizationSource: FixtureOrganization(organizationFor('pat')));
    World.shell.goTo(Section.projects);
    await World.settle(tester);
    final machine = World.machines.current.name;
    expect(
      find.byKey(ValueKey<String>('project $machine/$defaultProject')),
      findsOneWidget,
      reason: 'the list is drawn',
    );
    expect(find.byKey(const ValueKey('my-project other')), findsNothing);
    expect(find.byKey(ValueKey<String>('project $machine/other')), findsNothing);
  });
}
